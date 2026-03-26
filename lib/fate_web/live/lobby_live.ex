defmodule FateWeb.LobbyLive do
  use FateWeb, :live_view

  alias Fate.Game.Bookmarks

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
        <h1
          class="text-4xl font-bold text-amber-100 mb-4"
          style="font-family: 'Permanent Marker', cursive;"
        >
          Fate Table
        </h1>
        <p class="text-amber-200/50">Loading...</p>
      </div>
    </div>
    """
  end

  defp find_or_create_bookmark do
    case Bookmarks.find_latest_leaf() do
      {:ok, bookmark} -> bookmark.id
      :none -> bootstrap()
    end
  end

  defp bootstrap do
    alias Fate.Game.{Event, Bookmark, Participant, BookmarkParticipant}

    with {:ok, gm} <- Ash.create(Participant, %{name: "GM", color: "#ef4444"}, action: :create),
         {:ok, root_bmk_event} <-
           Ash.create(
             Event,
             %{
               type: :bookmark_create,
               description: "New Game",
               detail: %{"name" => "New Game"}
             },
             action: :append
           ),
         {:ok, null_scene} <-
           Ash.create(
             Event,
             %{
               parent_id: root_bmk_event.id,
               type: :scene_start,
               description: "Default scene",
               detail: %{
                 "scene_id" => Ash.UUID.generate(),
                 "name" => nil,
                 "description" => nil,
                 "gm_notes" => "NO SCENE"
               }
             },
             action: :append
           ),
         {:ok, root_bookmark} <-
           Ash.create(
             Bookmark,
             %{
               name: "New Game",
               head_event_id: null_scene.id
             },
             action: :create
           ),
         {:ok, _bp} <-
           Ash.create(
             BookmarkParticipant,
             %{
               bookmark_id: root_bookmark.id,
               participant_id: gm.id,
               role: :gm,
               seat_index: 0
             },
             action: :create
           ) do
      case Fate.Game.Demo.create_from_root(root_bookmark, gm) do
        {:ok, demo_bookmark} -> demo_bookmark.id
        _ -> root_bookmark.id
      end
    else
      _ -> raise "Failed to bootstrap"
    end
  end
end
