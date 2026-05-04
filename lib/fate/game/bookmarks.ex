defmodule Fate.Game.Bookmarks do
  @moduledoc """
  Context functions for bookmark lifecycle operations:
  listing, forking, archiving, loading participants, and bootstrapping.

  Mutating functions in this module broadcast on two PubSub channels:

    * `bookmark_participants:#{"<bookmark_id>"}` — `{:participants_updated, [BookmarkParticipant.t]}`
    * `bookmarks:list` — `{:bookmarks_updated, [Bookmark.t]}`

  Subscribe to the relevant channel via `subscribe_participants/1` or
  `subscribe_bookmarks_list/0`.
  """

  alias Fate.Game
  alias Fate.Game.{Bookmark, BookmarkParticipant}

  require Ash.Query

  @participants_topic_prefix "bookmark_participants:"
  @bookmarks_topic "bookmarks:list"

  def subscribe_participants(bookmark_id),
    do: Phoenix.PubSub.subscribe(Fate.PubSub, @participants_topic_prefix <> bookmark_id)

  def subscribe_bookmarks_list,
    do: Phoenix.PubSub.subscribe(Fate.PubSub, @bookmarks_topic)

  def list_active do
    case Ash.read(
           Bookmark
           |> Ash.Query.filter(status: :active)
           |> Ash.Query.sort(created_at: :asc)
         ) do
      {:ok, bookmarks} -> bookmarks
      _ -> []
    end
  end

  def fork(bookmark_id, name \\ nil) do
    case Game.get_bookmark(bookmark_id) do
      {:ok, %{head_event_id: head_id, name: bm_name}} when head_id != nil ->
        fork_name = name || "Fork: #{bm_name}"
        create_child_bookmark(bookmark_id, fork_name)

      {:ok, _} ->
        {:error, :no_head_event}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Insert a new bookmark whose `bookmark_create` event sits on top of `parent_id`'s
  current head. Used by both the GM "Create Bookmark" button and `fork/2`.

  Options:

    * `:description` — optional bookmark description.
  """
  def create_child_bookmark(parent_id, name, opts \\ []) do
    description = Keyword.get(opts, :description)

    with {:ok, %Bookmark{head_event_id: head_id} = parent} when head_id != nil <-
           Game.get_bookmark(parent_id),
         {:ok, bmk_event} <-
           Game.append_event(%{
             parent_id: head_id,
             type: :bookmark_create,
             description: name,
             detail: %{"name" => name}
           }),
         {:ok, new_bm} <-
           Game.create_bookmark(%{
             name: name,
             description: description,
             head_event_id: bmk_event.id,
             parent_bookmark_id: parent.id
           }) do
      broadcast_bookmarks_list()
      {:ok, new_bm}
    else
      {:ok, _} -> {:error, :no_head_event}
      {:ok, nil} -> {:error, :not_found}
      other -> other
    end
  end

  def archive(bookmark_id) do
    case Game.get_bookmark(bookmark_id) do
      {:ok, bookmark} when bookmark != nil ->
        case Game.set_status(bookmark, %{status: :archived}) do
          {:ok, archived} ->
            broadcast_bookmarks_list()
            {:ok, archived}

          other ->
            other
        end

      _ ->
        {:error, :not_found}
    end
  end

  def load_participants(bookmark_id) do
    BookmarkParticipant
    |> Ash.Query.filter(bookmark_id: bookmark_id)
    |> Ash.Query.load(:participant)
    |> Ash.read!()
  rescue
    e ->
      require Logger
      Logger.error("Failed to load participants: #{inspect(e)}")
      []
  end

  @doc """
  Idempotently seat a participant at a bookmark.

  If they're already seated, returns `{:ok, :already_seated}` without inserting
  or broadcasting. Otherwise inserts a `BookmarkParticipant` row (auto-picking
  the next seat when `seat_index` is `nil`) and broadcasts a participants
  update.
  """
  def seat_participant(bookmark_id, participant_id, role, seat_index \\ nil) do
    role_atom = if is_atom(role), do: role, else: String.to_existing_atom(to_string(role))

    case Ash.read(
           BookmarkParticipant
           |> Ash.Query.filter(bookmark_id: bookmark_id)
           |> Ash.Query.filter(participant_id: participant_id)
         ) do
      {:ok, [_ | _]} ->
        {:ok, :already_seated}

      {:ok, []} ->
        seat = seat_index || next_seat_index(bookmark_id)

        case Game.create_bookmark_participant(%{
               bookmark_id: bookmark_id,
               participant_id: participant_id,
               role: role_atom,
               seat_index: seat
             }) do
          {:ok, bp} ->
            broadcast_participants(bookmark_id)
            {:ok, bp}

          other ->
            other
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Unseat a participant from a bookmark. If the participant is no longer seated
  at any other bookmark, the underlying `Participant` record is also deleted.

  Returns `{:ok, %{participant_deleted: bool}}` on success, or
  `{:error, :not_seated}` if no matching join row exists.
  """
  def unseat_participant(bookmark_id, participant_id) do
    case Ash.read(
           BookmarkParticipant
           |> Ash.Query.filter(bookmark_id: bookmark_id)
           |> Ash.Query.filter(participant_id: participant_id)
         ) do
      {:ok, [bp | _]} ->
        case Game.delete_bookmark_participant(bp) do
          :ok ->
            participant_deleted? = maybe_delete_orphaned_participant(participant_id)
            broadcast_participants(bookmark_id)
            {:ok, %{participant_deleted: participant_deleted?}}

          other ->
            other
        end

      {:ok, []} ->
        {:error, :not_seated}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def next_seat_index(bookmark_id) do
    case Ash.read(
           BookmarkParticipant
           |> Ash.Query.filter(bookmark_id: bookmark_id)
         ) do
      {:ok, bps} -> length(bps)
      _ -> 0
    end
  end

  defp maybe_delete_orphaned_participant(participant_id) do
    case Ash.read(
           BookmarkParticipant
           |> Ash.Query.filter(participant_id: participant_id)
         ) do
      {:ok, []} ->
        case Game.get_participant(participant_id) do
          {:ok, %Fate.Game.Participant{} = participant} ->
            case Game.delete_participant(participant) do
              :ok -> true
              _ -> false
            end

          _ ->
            false
        end

      _ ->
        false
    end
  end

  defp broadcast_participants(bookmark_id) do
    Phoenix.PubSub.broadcast(
      Fate.PubSub,
      @participants_topic_prefix <> bookmark_id,
      {:participants_updated, load_participants(bookmark_id)}
    )
  end

  defp broadcast_bookmarks_list do
    Phoenix.PubSub.broadcast(
      Fate.PubSub,
      @bookmarks_topic,
      {:bookmarks_updated, list_active()}
    )
  end

  def leaf_bookmark?(bookmark) do
    case Ash.read(
           Bookmark
           |> Ash.Query.filter(parent_bookmark_id: bookmark.id, status: :active)
         ) do
      {:ok, []} -> true
      _ -> false
    end
  end

  def find_latest_leaf do
    case Ash.read(
           Bookmark
           |> Ash.Query.filter(status: :active)
           |> Ash.Query.load(:head_event)
           |> Ash.Query.sort(created_at: :desc)
         ) do
      {:ok, [_ | _] = bookmarks} ->
        bookmarks
        |> Enum.filter(&leaf_bookmark?/1)
        |> Enum.max_by(fn b -> b.head_event && b.head_event.timestamp end, DateTime, fn -> nil end)
        |> case do
          nil -> {:ok, List.first(bookmarks)}
          b -> {:ok, b}
        end

      _ ->
        :none
    end
  end
end
