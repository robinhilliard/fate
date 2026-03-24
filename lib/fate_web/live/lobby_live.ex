defmodule FateWeb.LobbyLive do
  use FateWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      branch_id = find_or_create_branch()

      {:ok, push_navigate(socket, to: ~p"/table/#{branch_id}")}
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

  defp find_or_create_branch do
    case Ash.read(Fate.Game.Branch, filter: [status: :active], load: [:head_event]) do
      {:ok, [_ | _] = branches} ->
        branches
        |> Enum.max_by(fn b -> b.head_event && b.head_event.timestamp end, DateTime, fn -> nil end)
        |> Map.get(:id)

      _ ->
        create_empty_branch()
    end
  end

  defp create_empty_branch do
    alias Fate.Game.{Event, Branch, Participant, BranchParticipant}

    with {:ok, gm} <- Ash.create(Participant, %{name: "GM", color: "#ef4444"}, action: :create),
         {:ok, root} <- Ash.create(Event, %{
           type: :create_campaign,
           description: "New Campaign",
           detail: %{"campaign_name" => "New Campaign"}
         }, action: :append),
         {:ok, branch} <- Ash.create(Branch, %{
           name: "Main",
           head_event_id: root.id
         }, action: :create),
         {:ok, _bp} <- Ash.create(BranchParticipant, %{
           branch_id: branch.id,
           participant_id: gm.id,
           role: :gm,
           seat_index: 0
         }, action: :create) do
      branch.id
    else
      _ -> raise "Failed to create initial branch"
    end
  end
end
