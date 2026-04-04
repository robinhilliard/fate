defmodule Fate.Text.StopWords do
  @moduledoc """
  Curated English stop words for compact tag generation (articles, common prepositions).
  """

  @words MapSet.new(~w(
    a an the and or but if then else
    of at to in on for from with by as is was are were be been being
    it its this that these those than into onto upon over under again further
    once here there when where why how all each every both few more most other some such
    no nor not only own same so too very can could should would will just
  ))

  @doc """
  Returns true if `word` (already lowercased) is a stop word.
  """
  def stop_word?(word) when is_binary(word), do: MapSet.member?(@words, word)
  def stop_word?(_), do: false
end
