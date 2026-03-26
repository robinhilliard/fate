defmodule FateWeb.Helpers do
  @moduledoc """
  Shared helper functions for LiveViews.
  """

  def localhost?(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: {127, 0, 0, 1}} -> true
      %{address: {0, 0, 0, 0, 0, 0, 0, 1}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end
