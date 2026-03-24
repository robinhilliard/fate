defmodule FateWeb.BranchesLive do
  use FateWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    branches = load_branches()
    bookmarks = load_bookmarks()

    {:ok,
     socket
     |> assign(:branches, branches)
     |> assign(:bookmarks, bookmarks)
     |> assign(:modal, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen p-8" style="background: #2d1f0e; color: #e8dcc8;">
      <h1
        class="text-4xl text-amber-100 mb-8"
        style="font-family: 'Permanent Marker', cursive;"
      >
        Fate Branches
      </h1>

      <%= if @branches == [] do %>
        <p class="text-amber-200/70 mb-4">No branches yet. Create your first campaign.</p>
        <button
          phx-click="create_demo"
          class="px-6 py-3 bg-amber-700 text-amber-100 rounded-lg hover:bg-amber-600 transition"
        >
          Create Demo Campaign
        </button>
      <% else %>
        <div class="grid gap-4 max-w-2xl">
          <%= for branch <- @branches do %>
            <div class="p-4 rounded-lg bg-amber-900/40 border border-amber-700/30">
              <div class="flex items-center gap-3">
                <.link
                  navigate={~p"/table/#{branch.id}"}
                  class="flex-1 hover:text-amber-200 transition"
                >
                  <div class="text-lg text-amber-100 font-bold" style="font-family: 'Patrick Hand', cursive;">
                    {branch.name}
                  </div>
                  <div class="text-xs text-amber-200/40 mt-0.5">
                    {if branch.head_event, do: Calendar.strftime(branch.head_event.timestamp, "%b %d, %H:%M"), else: "—"}
                  </div>
                </.link>
                <div class="flex gap-1">
                  <button
                    phx-click="bookmark_branch"
                    phx-value-branch-id={branch.id}
                    class="px-2 py-1 bg-amber-800/50 hover:bg-amber-700/50 rounded text-xs text-amber-200/70 transition"
                  >
                    Bookmark
                  </button>
                  <%= if length(@branches) > 1 do %>
                    <button
                      phx-click="archive_branch"
                      phx-value-branch-id={branch.id}
                      data-confirm="Archive this branch?"
                      class="px-2 py-1 bg-red-900/40 hover:bg-red-800/40 rounded text-xs text-red-300/70 transition"
                    >
                      Archive
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Bookmarks section --%>
        <%= if @bookmarks != [] do %>
          <h2 class="text-2xl text-amber-100 mt-10 mb-4" style="font-family: 'Permanent Marker', cursive;">
            Bookmarks
          </h2>
          <div class="grid gap-3 max-w-2xl">
            <%= for bm <- @bookmarks do %>
              <div class="flex items-center gap-3 p-3 rounded-lg bg-amber-900/20 border border-amber-700/20">
                <div class="flex-1">
                  <div class="text-sm text-amber-100 font-bold" style="font-family: 'Patrick Hand', cursive;">{bm.name}</div>
                  <%= if bm.description do %>
                    <div class="text-xs text-amber-200/40">{bm.description}</div>
                  <% end %>
                  <div class="text-xs text-amber-200/25 mt-0.5">
                    {Calendar.strftime(bm.created_at, "%b %d, %H:%M")}
                  </div>
                </div>
                <button
                  phx-click="fork_from_bookmark"
                  phx-value-bookmark-id={bm.id}
                  class="px-2 py-1 bg-green-900/40 hover:bg-green-800/40 rounded text-xs text-green-300/70 transition"
                >
                  Fork
                </button>
                <button
                  phx-click="delete_bookmark"
                  phx-value-bookmark-id={bm.id}
                  data-confirm="Delete this bookmark?"
                  class="px-2 py-1 bg-red-900/30 hover:bg-red-800/30 rounded text-xs text-red-300/50 transition"
                >
                  ✕
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>

      <%!-- Bookmark modal --%>
      <%= if @modal == "bookmark" do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
          <div class="bg-amber-950 border border-amber-700/40 rounded-xl p-6 w-96 shadow-2xl">
            <h3 class="text-lg font-bold text-amber-100 mb-4" style="font-family: 'Permanent Marker', cursive;">
              Create Bookmark
            </h3>
            <form phx-submit="submit_bookmark" class="space-y-3">
              <input type="hidden" name="branch_id" value={@bookmark_branch_id} />
              <div>
                <label class="block text-sm text-amber-200/70 mb-1">Name</label>
                <input type="text" name="name" placeholder="Before the fight"
                  class="w-full px-3 py-2 bg-amber-900/30 border border-amber-700/30 rounded-lg text-amber-100 text-sm placeholder-amber-200/20" />
              </div>
              <div>
                <label class="block text-sm text-amber-200/70 mb-1">Description (optional)</label>
                <input type="text" name="description" placeholder=""
                  class="w-full px-3 py-2 bg-amber-900/30 border border-amber-700/30 rounded-lg text-amber-100 text-sm placeholder-amber-200/20" />
              </div>
              <div class="flex gap-2 pt-2">
                <button type="submit" class="flex-1 py-2 bg-green-800/60 border border-green-600/30 rounded-lg hover:bg-green-700/60 text-green-200 font-bold text-sm">Create</button>
                <button type="button" phx-click="close_modal" class="flex-1 py-2 bg-red-900/40 border border-red-700/30 rounded-lg hover:bg-red-800/40 text-red-200 text-sm">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("bookmark_branch", %{"branch-id" => branch_id}, socket) do
    {:noreply, socket |> assign(:modal, "bookmark") |> assign(:bookmark_branch_id, branch_id)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :modal, nil)}
  end

  def handle_event("submit_bookmark", %{"branch_id" => branch_id, "name" => name} = params, socket) do
    case Ash.get(Fate.Game.Branch, branch_id, not_found_error?: false) do
      {:ok, %{head_event_id: event_id}} when event_id != nil ->
        Ash.create(Fate.Game.Bookmark, %{
          name: name,
          description: params["description"],
          event_id: event_id
        }, action: :create)

      _ ->
        :ok
    end

    {:noreply,
     socket
     |> assign(:modal, nil)
     |> assign(:bookmarks, load_bookmarks())}
  end

  def handle_event("fork_from_bookmark", %{"bookmark-id" => bookmark_id}, socket) do
    case Ash.get(Fate.Game.Bookmark, bookmark_id, not_found_error?: false) do
      {:ok, %{event_id: event_id, name: bm_name}} when event_id != nil ->
        case Ash.create(Fate.Game.Branch, %{
          name: "Fork: #{bm_name}",
          head_event_id: event_id
        }, action: :create) do
          {:ok, branch} ->
            {:noreply,
             socket
             |> assign(:branches, load_branches())
             |> put_flash(:info, "Forked branch: #{branch.name}")}

          _ ->
            {:noreply, put_flash(socket, :error, "Failed to fork")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Bookmark not found")}
    end
  end

  def handle_event("delete_bookmark", %{"bookmark-id" => bookmark_id}, socket) do
    case Ash.get(Fate.Game.Bookmark, bookmark_id, not_found_error?: false) do
      {:ok, bookmark} when bookmark != nil ->
        Ash.destroy!(bookmark, action: :delete)
      _ -> :ok
    end

    {:noreply, assign(socket, :bookmarks, load_bookmarks())}
  end

  def handle_event("archive_branch", %{"branch-id" => branch_id}, socket) do
    case Ash.get(Fate.Game.Branch, branch_id, not_found_error?: false) do
      {:ok, branch} when branch != nil ->
        Ash.update!(branch, %{status: :archived}, action: :set_status)
      _ -> :ok
    end

    {:noreply, assign(socket, :branches, load_branches())}
  end

  @impl true
  def handle_event("create_demo", _params, socket) do
    case create_demo_campaign() do
      {:ok, branch} ->
        {:noreply, push_navigate(socket, to: ~p"/table/#{branch.id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  defp create_demo_campaign do
    alias Fate.Game.{Event, Branch, Participant, BranchParticipant}

    cynere_id = Ash.UUID.generate()
    landon_id = Ash.UUID.generate()
    zird_id = Ash.UUID.generate()
    sword_id = Ash.UUID.generate()
    shield_id = Ash.UUID.generate()
    staff_id = Ash.UUID.generate()
    storm_id = Ash.UUID.generate()

    with {:ok, gm} <-
           Ash.create(Participant, %{name: "Robin", color: "#ef4444"}, action: :create),
         {:ok, player} <-
           Ash.create(Participant, %{name: "Ruthie", color: "#2563eb"}, action: :create),
         {:ok, player2} <-
           Ash.create(Participant, %{name: "Lenny", color: "#16a34a"}, action: :create),
         {:ok, player3} <-
           Ash.create(Participant, %{name: "Amanda", color: "#d946ef"}, action: :create),
         {:ok, root} <-
           Ash.create(Event, %{
             type: :create_campaign,
             description: "Sindral Reach",
             detail: %{"campaign_name" => "Sindral Reach"}
           }, action: :append),
         {:ok, sys} <-
           Ash.create(Event, %{
             parent_id: root.id,
             type: :set_system,
             description: "Fate Core",
             detail: %{"system" => "core"}
           }, action: :append),
         {:ok, npc} <-
           Ash.create(Event, %{
             parent_id: sys.id,
             type: :entity_create,
             description: "Create Barathar",
             detail: %{
               "entity_id" => Ash.UUID.generate(),
               "name" => "Barathar",
               "kind" => "npc",
               "fate_points" => 3,
               "color" => "#dc2626",
               "aspects" => [
                 %{"description" => "Smuggler Queen of the Sindral Reach", "role" => "high_concept"},
                 %{"description" => "Trusted by No One", "role" => "trouble"}
               ],
               "skills" => %{
                 "Deceive" => 4,
                 "Contacts" => 3,
                 "Resources" => 3,
                 "Will" => 2,
                 "Fight" => 2,
                 "Notice" => 1
               },
               "stunts" => [
                 %{"name" => "Network of Informants", "effect" => "+2 to Contacts when gathering information in port cities"}
               ],
               "stress_tracks" => [
                 %{"label" => "physical", "boxes" => 2},
                 %{"label" => "mental", "boxes" => 3}
               ]
             }
           }, action: :append),
         {:ok, pc} <-
           Ash.create(Event, %{
             parent_id: npc.id,
             type: :entity_create,
             description: "Create Cynere",
             detail: %{
               "entity_id" => cynere_id,
               "name" => "Cynere",
               "kind" => "pc",
               "fate_points" => 3,
               "refresh" => 3,
               "color" => "#2563eb",
               "controller_id" => player.id,
               "aspects" => [
                 %{"description" => "Infamous Girl with Sword", "role" => "high_concept"},
                 %{"description" => "Tempted by Shiny Things", "role" => "trouble"},
                 %{"description" => "Rivals in the Underworld", "role" => "additional"}
               ],
               "skills" => %{
                 "Fight" => 4,
                 "Athletics" => 3,
                 "Burglary" => 3,
                 "Provoke" => 2,
                 "Stealth" => 2,
                 "Notice" => 1,
                 "Physique" => 1
               },
               "stunts" => [
                 %{"name" => "Master Swordswoman", "effect" => "+2 to Fight when dueling one-on-one"}
               ],
               "stress_tracks" => [
                 %{"label" => "physical", "boxes" => 3},
                 %{"label" => "mental", "boxes" => 2}
               ]
             }
           }, action: :append),
         {:ok, scene} <-
           Ash.create(Event, %{
             parent_id: pc.id,
             type: :scene_start,
             description: "Dockside Warehouse",
             detail: %{
               "scene_id" => Ash.UUID.generate(),
               "name" => "Dockside Warehouse",
               "description" => "A run-down warehouse at the edge of the docks. Crates everywhere. The loading door is open to the water.",
               "zones" => [
                 %{"name" => "Main Floor", "sort_order" => 0},
                 %{"name" => "Upper Catwalk", "sort_order" => 1},
                 %{"name" => "Loading Dock", "sort_order" => 2}
               ],
               "aspects" => [
                 %{"description" => "Heavy Crates Everywhere", "role" => "situation"},
                 %{"description" => "Open to the Water", "role" => "situation"},
                 %{"description" => "Poorly Lit", "role" => "situation"}
               ],
               "gm_notes" => "Barathar waits on the upper catwalk with Og. The smuggled goods are in crates near the loading dock. If the PCs make noise, 4 thugs emerge from the main floor crates."
             }
           }, action: :append),
         # Landon — Lenny's character
         {:ok, pc2} <-
           Ash.create(Event, %{
             parent_id: scene.id,
             type: :entity_create,
             description: "Create Landon",
             detail: %{
               "entity_id" => landon_id,
               "name" => "Landon",
               "kind" => "pc",
               "fate_points" => 3,
               "refresh" => 3,
               "color" => "#16a34a",
               "controller_id" => player2.id,
               "aspects" => [
                 %{"description" => "An Honest-to-Gods Swordsman", "role" => "high_concept"},
                 %{"description" => "I Owe Old Finn Everything", "role" => "trouble"},
                 %{"description" => "Muscle for Hire", "role" => "additional"}
               ],
               "skills" => %{
                 "Fight" => 4,
                 "Physique" => 3,
                 "Athletics" => 3,
                 "Will" => 2,
                 "Provoke" => 2,
                 "Notice" => 1,
                 "Contacts" => 1
               },
               "stunts" => [
                 %{"name" => "Heavy Hitter", "effect" => "+2 to Fight when using a two-handed weapon"}
               ],
               "stress_tracks" => [
                 %{"label" => "physical", "boxes" => 4},
                 %{"label" => "mental", "boxes" => 2}
               ]
             }
           }, action: :append),
         # Landon's sword (sub-entity / extra)
         {:ok, sword} <-
           Ash.create(Event, %{
             parent_id: pc2.id,
             type: :entity_create,
             description: "Create Landon's Greatsword",
             detail: %{
               "entity_id" => sword_id,
               "name" => "Heartsplitter",
               "kind" => "item",
               "color" => "#16a34a",
               "controller_id" => player2.id,
               "parent_entity_id" => landon_id,
               "aspects" => [
                 %{"description" => "Ancient Blade of the North", "role" => "high_concept"}
               ],
               "stunts" => [
                 %{"name" => "Rending Strike", "effect" => "Once per scene, add +2 shifts to a successful Fight attack"}
               ]
             }
           }, action: :append),
         # Landon's shield
         {:ok, shield} <-
           Ash.create(Event, %{
             parent_id: sword.id,
             type: :entity_create,
             description: "Create Landon's Shield",
             detail: %{
               "entity_id" => shield_id,
               "name" => "Battered Kite Shield",
               "kind" => "item",
               "color" => "#16a34a",
               "controller_id" => player2.id,
               "parent_entity_id" => landon_id,
               "aspects" => [
                 %{"description" => "Dented but Dependable", "role" => "high_concept"}
               ]
             }
           }, action: :append),
         # Zird — Amanda's character
         {:ok, pc3} <-
           Ash.create(Event, %{
             parent_id: shield.id,
             type: :entity_create,
             description: "Create Zird the Arcane",
             detail: %{
               "entity_id" => zird_id,
               "name" => "Zird the Arcane",
               "kind" => "pc",
               "fate_points" => 3,
               "refresh" => 2,
               "color" => "#d946ef",
               "controller_id" => player3.id,
               "aspects" => [
                 %{"description" => "Wizard of the Collegia Arcana", "role" => "high_concept"},
                 %{"description" => "Rivals in the Collegia", "role" => "trouble"},
                 %{"description" => "If I Haven't Been There I've Read About It", "role" => "additional"},
                 %{"description" => "Not the Face!", "role" => "additional"}
               ],
               "skills" => %{
                 "Lore" => 4,
                 "Will" => 3,
                 "Investigate" => 3,
                 "Crafts" => 2,
                 "Empathy" => 2,
                 "Notice" => 2,
                 "Rapport" => 1
               },
               "stunts" => [
                 %{"name" => "Arcane Shield", "effect" => "Use Lore to defend against physical attacks when you can invoke a magical ward"},
                 %{"name" => "Scholar's Eye", "effect" => "+2 to Investigate when examining magical artifacts"}
               ],
               "stress_tracks" => [
                 %{"label" => "physical", "boxes" => 2},
                 %{"label" => "mental", "boxes" => 4}
               ]
             }
           }, action: :append),
         # Zird's staff (extra)
         {:ok, staff} <-
           Ash.create(Event, %{
             parent_id: pc3.id,
             type: :entity_create,
             description: "Create Zird's Staff",
             detail: %{
               "entity_id" => staff_id,
               "name" => "Staff of the Collegia",
               "kind" => "item",
               "color" => "#d946ef",
               "controller_id" => player3.id,
               "parent_entity_id" => zird_id,
               "aspects" => [
                 %{"description" => "Focus of Arcane Power", "role" => "high_concept"}
               ],
               "stunts" => [
                 %{"name" => "Channelled Blast", "effect" => "Once per scene, use Lore instead of Shoot for a ranged attack"}
               ]
             }
           }, action: :append),
         # The Storm — bronze rule entity
         {:ok, storm} <-
           Ash.create(Event, %{
             parent_id: staff.id,
             type: :entity_create,
             description: "Create the Storm",
             detail: %{
               "entity_id" => storm_id,
               "name" => "The Howling Gale",
               "kind" => "hazard",
               "color" => "#64748b",
               "aspects" => [
                 %{"description" => "Relentless Fury of the Sea", "role" => "high_concept"},
                 %{"description" => "The Eye Passes Over", "role" => "trouble"}
               ],
               "skills" => %{
                 "Attack" => 3,
                 "Overcome" => 4
               },
               "stress_tracks" => [
                 %{"label" => "intensity", "boxes" => 4}
               ]
             }
           }, action: :append),
         # Og — hidden NPC, lurking in the warehouse
         {:ok, og} <-
           Ash.create(Event, %{
             parent_id: storm.id,
             type: :entity_create,
             description: "Create Og",
             detail: %{
               "entity_id" => Ash.UUID.generate(),
               "name" => "Og the Strong",
               "kind" => "npc",
               "fate_points" => 2,
               "color" => "#92400e",
               "aspects" => [
                 %{"description" => "Barathar's Loyal Enforcer", "role" => "high_concept", "hidden" => true},
                 %{"description" => "Dumb as a Bag of Hammers", "role" => "trouble", "hidden" => true}
               ],
               "skills" => %{
                 "Fight" => 3,
                 "Physique" => 3,
                 "Athletics" => 2,
                 "Notice" => 1
               },
               "stress_tracks" => [
                 %{"label" => "physical", "boxes" => 3},
                 %{"label" => "mental", "boxes" => 2}
               ]
             }
           }, action: :append),
         {:ok, branch} <-
           Ash.create(Branch, %{
             name: "Sindral Reach — Demo",
             head_event_id: og.id
           }, action: :create),
         {:ok, _gm_bp} <-
           Ash.create(BranchParticipant, %{
             branch_id: branch.id,
             participant_id: gm.id,
             role: :gm,
             seat_index: 0
           }, action: :create),
         {:ok, _bp} <-
           Ash.create(BranchParticipant, %{
             branch_id: branch.id,
             participant_id: player.id,
             role: :player,
             seat_index: 1
           }, action: :create),
         {:ok, _bp2} <-
           Ash.create(BranchParticipant, %{
             branch_id: branch.id,
             participant_id: player2.id,
             role: :player,
             seat_index: 2
           }, action: :create),
         {:ok, _bp3} <-
           Ash.create(BranchParticipant, %{
             branch_id: branch.id,
             participant_id: player3.id,
             role: :player,
             seat_index: 3
           }, action: :create) do
      {:ok, branch}
    end
  end

  defp load_branches do
    case Ash.read(Fate.Game.Branch, filter: [status: :active], load: [:head_event]) do
      {:ok, branches} -> branches
      _ -> []
    end
  end

  defp load_bookmarks do
    require Ash.Query

    case Ash.read(Fate.Game.Bookmark |> Ash.Query.sort(created_at: :desc)) do
      {:ok, bookmarks} -> bookmarks
      _ -> []
    end
  end
end
