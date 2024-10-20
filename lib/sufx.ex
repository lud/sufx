defmodule Sufx do
  defstruct tree: nil, compressed?: false

  @type t :: %__MODULE__{tree: map, compressed?: boolean()}
  @type tokens :: Enumerable.t({String.t(), term})

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

  @spec new :: t
  def new, do: %__MODULE__{tree: tree()}

  @spec new(tokens) :: t
  def new(tokens) do
    tree =
      Enum.reduce(tokens, tree(), fn {phrase, value}, tree ->
        _insert(tree, phrase, value)
      end)

    %__MODULE__{tree: tree}
  end

  defp tree, do: %{}

  @spec insert(t, String.t(), term) :: t
  def insert(%__MODULE__{compressed?: true}, _phrase, _value) do
    # Inserting in a compressed tree actually does work but leads to duplicated
    # keys at the same level, one as head of the list key and one as a bare key.
    #
    # As long as we use maps as data storage we cannot support clean trees as we
    # cannot match on map key [^head|_] only.
    raise ArgumentError, "tried to insert value in compressed Sufx tree"
  end

  def insert(sufx, phrase, value) do
    %__MODULE__{sufx | tree: _insert(sufx.tree, phrase, value)}
  end

  defp _insert(tree, phrase, value) do
    graphemes = to_graphemes(phrase)
    add_graphemes(tree, graphemes, value)
  end

  @spec to_graphemes(String.t()) :: [String.grapheme()]
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

  def search(sufx, phrase)

  def search(_, "") do
    []
  end

  def search(sufx, phrase) do
    graphemes = to_graphemes(phrase)

    case sufx.compressed? do
      true -> match_graphemes_comp(sufx.tree, graphemes, [])
      false -> match_graphemes(sufx.tree, graphemes, [])
    end
  end

  def search_ranked(sufx, phrase)

  def search_ranked(_, "") do
    []
  end

  def search_ranked(sufx, phrase) do
    graphemes = to_graphemes(phrase)

    # temporary impl for benchmark
    case sufx.compressed? do
      true -> match_graphemes_comp_rank(sufx.tree, graphemes, 0, 0, [])
      false -> match_graphemes_rank(sufx.tree, graphemes, 0, 0, [])
    end
  end

  @doc """
  Returns the given list of ranked results sorted by descending rank order.

  Note that the order may slightly differ from an implementation with
  `Enum.sort_by/3` due to optimizations.
  """
  def sort_by_rank(results) do
    # Depending on the sort algorithm, there can be different ordering if
    # rankings are the same. Sorting ascending and reversing is not the same as
    # sorting descending, given the same input list.
    #
    # In our case we do not care about preserving the orginal ordering between
    # items with the same ranking, as this ordering comes from the ordering in
    # the tree maps, which as for any map, should not be counted on.
    Enum.reverse(List.keysort(results, 1, :asc))
  end

  # -- Base algorithm ---------------------------------------------------------

  defp match_graphemes(tree, [h | t] = search, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {^h, subtree}, acc -> match_graphemes(subtree, t, acc)
      {:values, _values}, acc -> acc
      {_, subtree}, acc -> match_graphemes(subtree, search, acc)
    end)
  end

  defp match_graphemes(tree, [], acc) do
    collect_values(tree, acc)
  end

  # -- Ranking ----------------------------------------------------------------

  defp match_graphemes_rank(tree, [h | t] = search, streak, best, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, _values}, acc -> acc
      {^h, subtree}, acc -> match_graphemes_rank(subtree, t, streak + 1, best, acc)
      {_, subtree}, acc -> match_graphemes_rank(subtree, search, 0, max(best, streak), acc)
    end)
  end

  defp match_graphemes_rank(tree, [], streak, best, acc) do
    collect_values_rank(tree, max(streak, best), acc)
  end

  # -- Compressed -------------------------------------------------------------

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

  # -- Compressed with ranking ------------------------------------------------

  defp match_graphemes_comp_rank(tree, [h | t] = search, streak, best, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, _values}, acc ->
        acc

      {^h, subtree}, acc ->
        match_graphemes_comp_rank(subtree, t, streak + 1, best, acc)

      {list, subtree}, acc when is_list(list) ->
        match_graphemes_klist_rank(list, subtree, search, streak, best, acc)

      {_, subtree}, acc ->
        match_graphemes_comp_rank(subtree, search, 0, max(streak, best), acc)
    end)
  end

  defp match_graphemes_comp_rank(tree, [], streak, best, acc) do
    collect_values_rank(tree, max(streak, best), acc)
  end

  defp match_graphemes_klist_rank(tree_keys, subtree, search, streak, best, acc)

  defp match_graphemes_klist_rank([h | kt], subtree, [h | t], streak, best, acc) do
    match_graphemes_klist_rank(kt, subtree, t, streak + 1, best, acc)
  end

  defp match_graphemes_klist_rank([_ | kt], subtree, search, streak, best, acc) do
    match_graphemes_klist_rank(kt, subtree, search, 0, max(streak, best), acc)
  end

  # additional clause in ranking code when search graphemes are exhausted when
  # iteraring a compressed key.
  defp match_graphemes_klist_rank(_, subtree, [], streak, best, acc) do
    collect_values_rank(subtree, max(streak, best), acc)
  end

  defp match_graphemes_klist_rank([], subtree, search, streak, best, acc) do
    match_graphemes_comp_rank(subtree, search, streak, best, acc)
  end

  # -- Finalizers -------------------------------------------------------------

  defp collect_values(tree, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, values}, acc -> values ++ acc
      {_, subtree}, acc -> collect_values(subtree, acc)
    end)
  end

  defp collect_values_rank(tree, best, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, values}, acc -> with_ranks(values, best, acc)
      {_, subtree}, acc -> collect_values_rank(subtree, best, acc)
    end)
  end

  defp with_ranks([v | vs], best, acc) do
    with_ranks(vs, best, [{v, best} | acc])
  end

  defp with_ranks([], _, acc) do
    acc
  end
end
