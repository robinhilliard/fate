defmodule FateWeb.LobbyLive do
  use FateWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      bookmark_id = find_or_create_bookmark()
      {:ok, push_navigate(socket, to: ~p"/table/#{bookmark_id}")}
    else
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-screen" style="background: #2d1f0e;">
      <div class="text-center">
        <h1 class="text-4xl font-bold text-amber-100 mb-4" style="font-family: 'Permanent Marker', cursive;">
          Fate Table
        </h1>
        <p class="text-amber-200/50">Loading...</p>
      </div>
    </div>
    """
  end

  defp find_or_create_bookmark do
    require Ash.Query

    case Ash.read(Fate.Game.Bookmark
         |> Ash.Query.filter(status: :active)
         |> Ash.Query.load(:head_event)
         |> Ash.Query.sort(created_at: :desc)) do
      {:ok, [_ | _] = bookmarks} ->
        bookmarks
        |> Enum.filter(&leaf_bookmark?/1)
        |> Enum.max_by(fn b -> b.head_event && b.head_event.timestamp end, DateTime, fn -> nil end)
        |> case do
          nil -> List.first(bookmarks) |> Map.get(:id)
          b -> b.id
        end

      _ ->
        bootstrap()
    end
  end

  defp leaf_bookmark?(bookmark) do
    require Ash.Query

    case Ash.read(Fate.Game.Bookmark |> Ash.Query.filter(parent_bookmark_id: bookmark.id, status: :active)) do
      {:ok, []} -> true
      _ -> false
    end
  end

  defp bootstrap do
    alias Fate.Game.{Event, Bookmark, Participant, BookmarkParticipant}

    with {:ok, gm} <- Ash.create(Participant, %{name: "GM", color: "#ef4444"}, action: :create),
         {:ok, root_bmk_event} <- Ash.create(Event, %{
           type: :bookmark_create,
           description: "New Game",
           detail: %{"name" => "New Game"}
         }, action: :append),
         {:ok, null_scene} <- Ash.create(Event, %{
           parent_id: root_bmk_event.id,
           type: :scene_start,
           description: "Default scene",
           detail: %{
             "scene_id" => Ash.UUID.generate(),
             "name" => nil,
             "description" => nil,
             "gm_notes" => "NO SCENE"
           }
         }, action: :append),
         {:ok, root_bookmark} <- Ash.create(Bookmark, %{
           name: "New Game",
           head_event_id: null_scene.id
         }, action: :create),
         {:ok, _bp} <- Ash.create(BookmarkParticipant, %{
           bookmark_id: root_bookmark.id,
           participant_id: gm.id,
           role: :gm,
           seat_index: 0
         }, action: :create) do
      case FateWeb.BranchesLive.create_demo_from_root(root_bookmark, gm) do
        {:ok, demo_bookmark} -> demo_bookmark.id
        _ -> root_bookmark.id
      end
    else
      _ -> raise "Failed to bootstrap"
    end
  end
end
