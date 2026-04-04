defmodule Fate.Game.EntityKindTags do
  @moduledoc """
  Maps entity `kind` atoms to implicit hashtag suffixes for type-ahead (`#pc`, `#npc`, …).
  """

  @implicit %{
    pc: "pc",
    npc: "npc",
    vehicle: "vehicle",
    item: "item"
  }

  @doc """
  Returns the hashtag **suffix** (without `#`) for `kind`, or `nil` if not in the implicit set.
  """
  def hashtag_suffix(kind) when is_atom(kind), do: Map.get(@implicit, kind)

  def hashtag_suffix(kind) when is_binary(kind) do
    case String.downcase(kind) do
      "pc" -> "pc"
      "npc" -> "npc"
      "vehicle" -> "vehicle"
      "item" -> "item"
      _ -> nil
    end
  end

  def hashtag_suffix(_), do: nil

  @doc """
  Sorted unique suffixes for the kinds present in `kinds` (atoms or strings).
  """
  def implicit_suffixes_for_kinds(kinds) do
    kinds
    |> Enum.map(&normalize_kind/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&hashtag_suffix/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp normalize_kind(k) when is_atom(k), do: k

  defp normalize_kind(k) when is_binary(k) do
    String.to_existing_atom(String.downcase(k))
  rescue
    ArgumentError -> nil
  end

  defp normalize_kind(_), do: nil
end
