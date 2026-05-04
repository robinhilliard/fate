defmodule FateWeb.BranchesLive do
  use FateWeb, :live_view

  alias Fate.Game.Bookmarks

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Bookmarks.subscribe_bookmarks_list()
    {:ok, assign(socket, :bookmarks, Bookmarks.list_active())}
  end

  @impl true
  def handle_info({:bookmarks_updated, bookmarks}, socket) do
    {:noreply, assign(socket, :bookmarks, bookmarks)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen p-8" style="background: #2d1f0e; color: #e8dcc8;">
      <h1 class="text-4xl text-amber-100 mb-8" style="font-family: 'Permanent Marker', cursive;">
        Bookmarks
      </h1>

      <div class="flex gap-3 mb-6">
        <.link
          navigate={~p"/"}
          class="px-4 py-2 bg-amber-800/50 hover:bg-amber-700/50 rounded-lg text-amber-200 text-sm transition"
        >
          Back to Table
        </.link>
      </div>

      <%= if @bookmarks == [] do %>
        <p class="text-amber-200/50">
          No bookmarks yet. Navigate to
          <.link navigate={~p"/"} class="text-amber-300 underline">the table</.link>
          to bootstrap.
        </p>
      <% else %>
        <div class="grid gap-3 max-w-2xl">
          <%= for bm <- @bookmarks do %>
            <div class="p-4 rounded-lg bg-amber-900/40 border border-amber-700/30">
              <div class="flex items-center gap-3">
                <.link navigate={~p"/table/#{bm.id}"} class="flex-1 hover:text-amber-200 transition">
                  <div
                    class="text-lg text-amber-100 font-bold"
                    style="font-family: 'Patrick Hand', cursive;"
                  >
                    {bm.name}
                  </div>
                  <%= if bm.description do %>
                    <div class="text-xs text-amber-200/40">{bm.description}</div>
                  <% end %>
                  <div class="text-xs text-amber-200/25 mt-0.5">
                    {Calendar.strftime(bm.created_at, "%b %d, %H:%M")}
                  </div>
                </.link>
                <div class="flex gap-1">
                  <button
                    phx-click="fork_bookmark"
                    phx-value-bookmark-id={bm.id}
                    class="px-2 py-1 bg-green-900/40 hover:bg-green-800/40 rounded text-xs text-green-300/70 transition"
                  >
                    Create Bookmark
                  </button>
                  <button
                    phx-click="archive_bookmark"
                    phx-value-bookmark-id={bm.id}
                    data-confirm="Archive this bookmark?"
                    class="px-2 py-1 bg-red-900/40 hover:bg-red-800/40 rounded text-xs text-red-300/70 transition"
                  >
                    Archive
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("fork_bookmark", %{"bookmark-id" => bookmark_id}, socket) do
    case Bookmarks.fork(bookmark_id) do
      {:ok, _new_bm} ->
        {:noreply, put_flash(socket, :info, "Bookmark created")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create bookmark")}
    end
  end

  def handle_event("archive_bookmark", %{"bookmark-id" => bookmark_id}, socket) do
    Bookmarks.archive(bookmark_id)
    {:noreply, socket}
  end
end
