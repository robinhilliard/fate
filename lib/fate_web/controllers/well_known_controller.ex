defmodule FateWeb.WellKnownController do
  use FateWeb, :controller

  def not_found(conn, _params) do
    conn
    |> put_status(404)
    |> json(%{error: "Not found"})
  end
end
