defmodule Fate.Engine do
  @moduledoc """
  Central coordination module for game state.
  Loads events from the database, replays them into derived state,
  and broadcasts changes via PubSub.
  """

  alias Fate.Game
  alias Fate.Engine.{MentionCatalog, Replay}

  @pubsub Fate.PubSub

  def derive_state(bookmark_id) do
    with {:ok, bookmark} when bookmark != nil <- Game.get_bookmark(bookmark_id),
         {:ok, events} <- load_event_chain(bookmark.head_event_id) do
      {:ok, Replay.derive(bookmark_id, events)}
    else
      {:ok, nil} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Replays the full bookmark event chain through `event_id` (inclusive) and returns
  derived state as of immediately after that event. Used for event-log edit modals.
  """
  def state_through_event(bookmark_id, event_id) do
    with {:ok, bookmark} when bookmark != nil <- Game.get_bookmark(bookmark_id),
         {:ok, events} <- load_event_chain(bookmark.head_event_id) do
      case Enum.find_index(events, &(&1.id == event_id)) do
        nil ->
          {:error, :event_not_in_chain}

        idx ->
          prefix = Enum.take(events, idx + 1)
          {:ok, Replay.derive(bookmark_id, prefix)}
      end
    else
      {:ok, nil} -> {:error, :not_found}
      error -> error
    end
  end

  def append_event(bookmark_id, attrs) do
    with {:ok, bookmark} when bookmark != nil <- Game.get_bookmark(bookmark_id) do
      attrs = Map.put(attrs, :parent_id, bookmark.head_event_id)

      with {:ok, event} <- Game.append_event(attrs),
           {:ok, _bookmark} <- Game.advance_head(bookmark, %{head_event_id: event.id}),
           {:ok, state} <- derive_state(bookmark_id) do
        broadcast(bookmark_id, state)
        {:ok, state, event}
      end
    end
  end

  def load_event_chain(nil), do: {:ok, []}

  def load_event_chain(event_id) do
    query = """
    WITH RECURSIVE chain AS (
      SELECT * FROM events WHERE id = $1
      UNION ALL
      SELECT e.* FROM events e
      JOIN chain c ON e.id = c.parent_id
    )
    SELECT * FROM chain ORDER BY timestamp ASC
    """

    run_event_query(query, event_id)
  end

  @doc """
  Loads events from bookmark head back to (but not including) the nearest
  bookmark_create event. Used for player-visible event log.
  Filters to: all events inside scene boundaries + out-of-scene events
  involving non-GM-controlled entities. Template events are always hidden.
  """
  def load_player_events(bookmark_id) do
    with {:ok, bookmark} when bookmark != nil <- Game.get_bookmark(bookmark_id),
         {:ok, events} <- load_event_chain(bookmark.head_event_id),
         {:ok, state} <- {:ok, Replay.derive(bookmark_id, events)} do
      non_gm_entity_ids = non_gm_controlled_entity_ids(state)
      {:ok, filter_player_events(events, non_gm_entity_ids)}
    else
      _ -> {:ok, []}
    end
  end

  @template_event_types ~w(template_scene_create template_scene_modify template_zone_create template_zone_modify template_aspect_add template_entity_place)a

  defp filter_player_events(events, non_gm_entity_ids) do
    {filtered, _in_scene} =
      Enum.reduce(events, {[], false}, fn event, {acc, in_scene} ->
        cond do
          event.type == :active_scene_start ->
            {[event | acc], true}

          event.type == :active_scene_end ->
            {[event | acc], false}

          event.type == :bookmark_create ->
            {acc, in_scene}

          event.type in @template_event_types ->
            {acc, in_scene}

          in_scene ->
            {[event | acc], in_scene}

          true ->
            if event_involves_non_gm_entity?(event, non_gm_entity_ids) do
              {[event | acc], in_scene}
            else
              {acc, in_scene}
            end
        end
      end)

    Enum.reverse(filtered)
  end

  defp event_involves_non_gm_entity?(event, non_gm_entity_ids) do
    refs = Replay.event_entity_refs(event)
    not MapSet.disjoint?(refs, non_gm_entity_ids)
  end

  defp non_gm_controlled_entity_ids(state) do
    state.entities
    |> Enum.filter(fn {_id, entity} -> entity.controller_id != nil end)
    |> Enum.reject(fn {_id, entity} -> entity.kind == :npc end)
    |> Enum.map(fn {id, _entity} -> id end)
    |> MapSet.new()
  end

  defp run_event_query(sql, event_id) do
    {:ok, binary_id} = Ecto.UUID.dump(event_id)

    case Fate.Repo.query(sql, [binary_id]) do
      {:ok, %{rows: rows, columns: columns}} ->
        events =
          Enum.map(rows, fn row ->
            columns
            |> Enum.zip(row)
            |> Map.new()
            |> row_to_event()
          end)

        {:ok, events}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp row_to_event(row) do
    %{
      id: load_uuid(row["id"]),
      parent_id: load_uuid(row["parent_id"]),
      timestamp: row["timestamp"],
      type: parse_type(row["type"]),
      actor_id: row["actor_id"],
      target_id: row["target_id"],
      exchange_id: load_uuid(row["exchange_id"]),
      description: row["description"],
      detail: row["detail"]
    }
  end

  defp load_uuid(nil), do: nil

  defp load_uuid(<<_::128>> = binary) do
    {:ok, uuid} = Ecto.UUID.load(binary)
    uuid
  end

  defp load_uuid(string) when is_binary(string), do: string

  defp parse_type(type) when is_binary(type) do
    String.to_existing_atom(type)
  rescue
    ArgumentError -> :unknown
  end

  defp parse_type(type) when is_atom(type), do: type

  defp broadcast(bookmark_id, state) do
    Phoenix.PubSub.broadcast(@pubsub, "bookmark:#{bookmark_id}", {:state_updated, state})
    Phoenix.PubSub.broadcast(@pubsub, "mcp:state_changed", {:state_updated, bookmark_id})
  end

  def subscribe(bookmark_id) do
    Phoenix.PubSub.subscribe(@pubsub, "bookmark:#{bookmark_id}")
  end

  @doc """
  Builds @ / # type-ahead catalog from the full event chain at the bookmark head
  (includes stowed entities and ended scenes).
  """
  def mention_catalog(bookmark_id) when is_binary(bookmark_id) do
    with {:ok, bookmark} when bookmark != nil <- Game.get_bookmark(bookmark_id),
         {:ok, events} <- load_event_chain(bookmark.head_event_id) do
      {:ok, MentionCatalog.build(events)}
    else
      {:ok, nil} -> {:error, :not_found}
      error -> error
    end
  end

  def mention_catalog(_), do: {:error, :not_found}

  @doc """
  JSON payload for `data-mention-catalog` on type-ahead textareas.
  """
  def mention_catalog_json(nil), do: Jason.encode!(%{entities: [], hashtags: []})

  def mention_catalog_json(bookmark_id) when is_binary(bookmark_id) do
    case mention_catalog(bookmark_id) do
      {:ok, cat} -> Jason.encode!(cat)
      _ -> Jason.encode!(%{entities: [], hashtags: []})
    end
  end

  def mention_catalog_json(_), do: Jason.encode!(%{entities: [], hashtags: []})
end
