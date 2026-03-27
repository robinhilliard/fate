defmodule Fate.Game.Events do
  @moduledoc """
  Context functions for event lifecycle operations.
  """

  alias Fate.Game.{Event, Bookmark}

  require Ash.Query

  @doc """
  Move `event_id` to be immediately after `after_event_id` in the chain.
  Pass `nil` for `after_event_id` to move the event to the very beginning (root position).
  """
  def reorder(event_id, after_event_id, bookmark_id) do
    if event_id == after_event_id, do: throw(:noop)

    with {:ok, event} when event != nil <-
           Ash.get(Event, event_id, not_found_error?: false),
         {:ok, bookmark} when bookmark != nil <-
           Ash.get(Bookmark, bookmark_id, not_found_error?: false) do
      # Already in the right place?
      if event.parent_id == after_event_id, do: throw(:noop)

      # Snapshot who currently follows after_event_id BEFORE we splice anything
      {:ok, displaced} =
        if after_event_id do
          Ash.read(Event |> Ash.Query.filter(parent_id: after_event_id))
        else
          {:ok, []}
        end

      displaced = Enum.reject(displaced, &(&1.id == event_id))

      # Step 1: Splice event OUT of its current position
      {:ok, children} = Ash.read(Event |> Ash.Query.filter(parent_id: event_id))

      Enum.each(children, fn child ->
        Ash.update!(child, %{parent_id: event.parent_id}, action: :edit)
      end)

      if bookmark.head_event_id == event_id do
        Ash.update!(bookmark, %{head_event_id: event.parent_id}, action: :advance_head)
      end

      # Step 2: Splice event IN after after_event_id
      Ash.update!(event, %{parent_id: after_event_id}, action: :edit)

      Enum.each(displaced, fn next ->
        Ash.update!(next, %{parent_id: event_id}, action: :edit)
      end)

      # Step 3: Fix timestamp
      after_ts =
        if after_event_id do
          case Ash.get(Event, after_event_id, not_found_error?: false) do
            {:ok, a} when a != nil -> a.timestamp
            _ -> ~U[2000-01-01 00:00:00.000000Z]
          end
        else
          ~U[2000-01-01 00:00:00.000000Z]
        end

      next_ts =
        case displaced do
          [d | _] -> d.timestamp
          [] -> DateTime.add(after_ts, 1, :second)
        end

      diff_us = DateTime.diff(next_ts, after_ts, :microsecond)
      mid_ts = DateTime.add(after_ts, div(diff_us, 2), :microsecond)
      Ash.update!(event, %{timestamp: mid_ts}, action: :edit)

      # Step 4: Update bookmark head if the moved event is now the tail
      {:ok, bookmark} = Ash.get(Bookmark, bookmark_id, not_found_error?: false)

      {:ok, event_children} =
        Ash.read(Event |> Ash.Query.filter(parent_id: event_id))

      if event_children == [] do
        Ash.update!(bookmark, %{head_event_id: event_id}, action: :advance_head)
      end

      :ok
    else
      _ -> {:error, :not_found}
    end
  catch
    :noop -> :ok
  end

  def delete(event_id, bookmark_id) do
    with {:ok, event} when event != nil <-
           Ash.get(Event, event_id, not_found_error?: false) do
      {:ok, bookmark} = Ash.get(Bookmark, bookmark_id, not_found_error?: false)

      if bookmark && bookmark.head_event_id == event_id do
        Ash.update!(bookmark, %{head_event_id: event.parent_id}, action: :advance_head)
      end

      case Ash.read(Event |> Ash.Query.filter(parent_id: event_id)) do
        {:ok, children} ->
          Enum.each(children, fn child ->
            Ash.update!(child, %{parent_id: event.parent_id}, action: :edit)
          end)

        _ ->
          :ok
      end

      Ash.destroy(event, action: :delete)
    else
      _ -> {:error, :not_found}
    end
  end
end
