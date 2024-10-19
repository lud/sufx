defmodule Sufx do
  defstruct tree: nil, compressed?: false

  @space <<32>>
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

  def new(), do: %__MODULE__{tree: tree()}
  # a token is a tuple with {phrase :: binary, value :: term}
  def new(tokens) do
    tree =
      Enum.reduce(tokens, tree(), fn {phrase, value}, tree ->
        _insert(tree, phrase, value)
      end)

    %__MODULE__{tree: tree}
  end

  defp tree, do: %{}

  def insert(%__MODULE__{tree: tree} = sufx, phrase, value) do
    %{sufx | tree: _insert(tree, phrase, value)}
  end

  defp _insert(tree, phrase, value) do
    graphemes = to_graphemes(phrase)
    add_graphemes(tree, graphemes, value)
  end

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

  def find_values(sufx, phrase) do
    graphemes = to_graphemes(phrase)

    case sufx.compressed? do
      true -> match_graphemes_comp(sufx.tree, graphemes, [])
      false -> match_graphemes(sufx.tree, graphemes, [])
    end
  end

  IO.warn(
    "@todo add score by proximity: 'an' matches 'orange' with score=1, 'banana' with score=2"
  )

  defp match_graphemes(tree, [h | t] = search, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, _values}, acc -> acc
      {^h, subtree}, acc -> match_graphemes(subtree, t, acc)
      {_, subtree}, acc -> match_graphemes(subtree, search, acc)
    end)
  end

  defp match_graphemes(tree, [], acc) do
    collect_values(tree, acc)
  end

  defp match_graphemes_comp(tree, [h | t] = search, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, _values}, acc ->
        acc

      {^h, subtree}, acc ->
        match_graphemes_comp(subtree, t, acc)

      {list, subtree}, acc when is_list(list) ->
        match_graphemes_klist(list, subtree, search, acc)

      {_, subtree}, acc ->
        match_graphemes_comp(subtree, search, acc)
    end)
  end

  defp match_graphemes_comp(tree, [], acc) do
    collect_values(tree, acc)
  end

  defp match_graphemes_klist([h | kt], subtree, [h | t], acc) do
    match_graphemes_klist(kt, subtree, t, acc)
  end

  defp match_graphemes_klist([_ | kt], subtree, search, acc) do
    match_graphemes_klist(kt, subtree, search, acc)
  end

  defp match_graphemes_klist([], subtree, search, acc) do
    match_graphemes_comp(subtree, search, acc)
  end

  defp collect_values(tree, acc) do
    Enum.reduce(tree, acc, fn
      {:values, values}, acc2 -> values ++ acc2
      {_, subtree}, acc2 -> collect_values(subtree, acc2)
    end)
  end

  @doc "Replace levels with a single child to list map keys."

  # general case, more than one key
  def compress(%__MODULE__{compressed?: false} = sufx) do
    %{sufx | compressed?: true, tree: _compress(sufx.tree)}
  end

  defp _compress(tree) do
    Map.new(tree, fn
      {:values, _} = term ->
        term

      {k, v} ->
        case _compress(v) do
          %{values: _} = sub ->
            {k, sub}

          sub when map_size(sub) == 1 ->
            [{next_k, v}] = Map.to_list(sub)
            {[k | List.wrap(next_k)], v}

          sub ->
            {k, sub}
        end
    end)
  end
end
