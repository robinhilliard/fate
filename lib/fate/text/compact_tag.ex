defmodule Fate.Text.CompactTag do
  @moduledoc """
  Stop-word stripping + `Slug.slugify/2` with empty separator for stable compact tags
  (scene titles, entity names).
  """

  alias Fate.Text.StopWords

  @doc """
  Produces a lowercase alphanumeric slug with no separators, e.g. "The Grease Chariot" → "greasechariot".

  Falls back to slugifying the full title if all tokens are stop words or filtered text slugifies empty.
  """
  def from_title(title) when title in [nil, ""], do: ""

  def from_title(title) when is_binary(title) do
    trimmed = String.trim(title)
    if trimmed == "", do: "", else: from_title_nonempty(trimmed)
  end

  defp from_title_nonempty(title) do
    tokens =
      title
      |> String.downcase()
      |> String.split(~r/[^\p{L}\p{N}]+/u, trim: true)

    filtered = Enum.reject(tokens, &StopWords.stop_word?/1)
    body = filtered |> Enum.join(" ")

    slug =
      case Slug.slugify(body, separator: "") do
        nil -> ""
        s when s in ["", nil] -> ""
        s -> s
      end

    if slug != "" do
      slug
    else
      case Slug.slugify(title, separator: "") do
        nil -> ascii_fallback(title)
        s when s in ["", nil] -> ascii_fallback(title)
        s -> s
      end
    end
  end

  defp ascii_fallback(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "")
  end
end
