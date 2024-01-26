defmodule Sufx do
  @space " "
  @ws [
    "\u0009",
    "\u000A",
    "\u000B",
    "\u000C",
    "\u000D",
    "\u0020",
    "\u0085",
    "\u00A0",
    "\u1680",
    "\u180E",
    "\u2000",
    "\u2001",
    "\u2002",
    "\u2003",
    "\u2004",
    "\u2005",
    "\u2006",
    "\u2007",
    "\u2008",
    "\u2009",
    "\u200A",
    "\u200B",
    "\u200C",
    "\u200D",
    "\u2028",
    "\u2029",
    "\u202F",
    "\u205F",
    "\u2060",
    "\u3000",
    "\uFEFF"
  ]
  # a token is a tuple with {phrase :: binary, value :: term}
  def tree(tokens) do
    Enum.reduce(tokens, tree(), fn token, tree ->
      {phrase, value} = token
      graphemes = to_graphemes(phrase)
      add_graphemes(tree, graphemes, value)
    end)
  end

  def tree(), do: %{}

  def to_graphemes(phrase) do
    phrase
    |> String.trim()
    |> String.downcase()
    |> String.graphemes()
    |> Enum.map(&normalize_whitespace/1)
    |> shrink_whitespace()
  end

  defp normalize_whitespace(g) when g in @ws, do: @space
  defp normalize_whitespace(g), do: g

  defp shrink_whitespace([@space, @space | rest]), do: shrink_whitespace([@space | rest])
  defp shrink_whitespace([g | rest]), do: [g | shrink_whitespace(rest)]
  defp shrink_whitespace([]), do: []

  defp add_graphemes(tree, [h | t], value) do
    case tree do
      %{^h => subtree} -> Map.put(tree, h, add_graphemes(subtree, t, value))
      _ -> Map.put(tree, h, add_graphemes(tree(), t, value))
    end
  end

  defp add_graphemes(tree, [], value), do: Map.update(tree, :values, [value], &[value | &1])

  def find_values(tree, phrase) do
    graphemes = to_graphemes(phrase)
    match_graphemes(tree, graphemes, [])
  end

  defp match_graphemes(tree, [h | t] = gs, acc) do
    Enum.reduce(tree, acc, fn
      {:values, _values}, acc2 -> acc2
      {^h, subtree}, acc2 -> match_graphemes(subtree, t, acc2)
      {_, subtree}, acc2 -> match_graphemes(subtree, gs, acc2)
    end)
  end

  defp match_graphemes(tree, [], acc) do
    collect_values(tree, acc)
  end

  defp collect_values(tree, acc) do
    Enum.reduce(tree, acc, fn
      {:values, values}, acc2 -> values ++ acc2
      {_, subtree}, acc2 -> collect_values(subtree, acc2)
    end)
  end
end
