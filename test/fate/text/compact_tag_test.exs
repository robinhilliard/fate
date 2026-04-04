defmodule Fate.Text.CompactTagTest do
  use ExUnit.Case, async: true

  alias Fate.Text.CompactTag

  test "strips common stop words and concatenates" do
    assert CompactTag.from_title("The Grease Chariot") == "greasechariot"
  end

  test "fallback when all tokens are stop words" do
    assert CompactTag.from_title("The A An") != ""
  end

  test "empty and nil" do
    assert CompactTag.from_title("") == ""
    assert CompactTag.from_title(nil) == ""
  end

  test "unicode transliteration via slugify" do
    slug = CompactTag.from_title("Café Noir")
    assert is_binary(slug)
    assert slug != ""
  end
end
