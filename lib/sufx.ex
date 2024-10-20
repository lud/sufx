defmodule Sufx do
  @moduledoc """
  A generic string fuzzy matching utility.

  Please see examples in the [readme file](readme.html).
  """

  defstruct tree: nil, compressed?: false

  @type t :: %__MODULE__{tree: map, compressed?: boolean()}
  @type phrase :: String.t()
  @type pattern :: String.t()
  @type tokens :: Enumerable.t({phrase, term})

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

  @doc """
  Creates an new, empty suffix tree.
  """
  @spec new :: t
  def new, do: %__MODULE__{tree: tree()}

  @doc """
  Creates a new tree from tokens.

  Tokens are phrase/value pairs where the phrase is a string and the value any
  term.
  """
  @spec new(tokens) :: t
  def new(tokens) do
    tree =
      Enum.reduce(tokens, tree(), fn {phrase, value}, tree ->
        _insert(tree, phrase, value)
      end)

    %__MODULE__{tree: tree}
  end

  defp tree, do: %{}

  @doc """
  Inserts a new phrase/value pair in an existing tree.

  This function does not support compressed trees.
  """
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

  @doc false
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

  @doc """
  Compresses the given tree to a more memory and CPU efficient form.

  While memory footprint is optimized, and searches will be faster, a compressed
  tree does not support further insertion.
  """
  @spec compress(t) :: t
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

  @doc """
  Returns the original tree before compression.
  """
  @spec decompress(t) :: t
  def decompress(%__MODULE__{compressed?: true} = sufx) do
    %{sufx | compressed?: false, tree: _decompress(sufx.tree)}
  end

  defp _decompress(tree) do
    Map.new(tree, fn
      {:values, _} = term -> term
      {[h | []], v} -> {h, _decompress(v)}
      {[h | k], v} -> {h, _decompress(%{k => v})}
      {k, v} -> {k, _decompress(v)}
    end)
  end

  @doc """
  Matches all phrases in the tree with the given pattern and return all values
  associated with successfully matched phrases.

  Returns an empty list if the given pattern is an empty string.
  """
  @spec search(t, pattern) :: [term]
  def search(sufx, pattern)

  def search(_, "") do
    []
  end

  def search(sufx, pattern) do
    graphemes = to_graphemes(pattern)

    case sufx.compressed? do
      true -> match_graphemes_comp(sufx.tree, graphemes, [])
      false -> match_graphemes(sufx.tree, graphemes, [])
    end
  end

  @doc """
  This function has the same behaviour as `search/2` but the results are wrapped
  in a tuple where the first element is the search result value and the second
  element is the score.

  Note that the results are not ordered by score, and multiple results can have
  the same score.

  See `sort_by_score/1`.
  """
  @spec search_score(t, pattern) :: [{term, non_neg_integer}]
  def search_score(sufx, pattern)

  def search_score(_, "") do
    []
  end

  def search_score(sufx, pattern) do
    graphemes = to_graphemes(pattern)

    # temporary impl for benchmark
    case sufx.compressed? do
      true -> match_graphemes_comp_score(sufx.tree, graphemes, 0, 0, [])
      false -> match_graphemes_score(sufx.tree, graphemes, 0, 0, [])
    end
  end

  @doc """
  Returns the given list of scored results sorted by descending score order.

  Note that the order may slightly differ from an implementation with
  `Enum.sort_by/3` due to optimizations.

  The function does nothing special and you are totally free to sort the results
  in any other way.
  """
  @spec sort_by_score([{term, non_neg_integer}]) :: [{term, non_neg_integer}]
  def sort_by_score(results) do
    # Depending on the sort algorithm, there can be different ordering if
    # scorings are the same. Sorting ascending and reversing is not the same as
    # sorting descending, given the same input list.
    #
    # In our case we do not care about preserving the orginal ordering between
    # items with the same scoring, as this ordering comes from the ordering in
    # the tree maps, which as for any map, should not be relied on.
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

  # -- scoring ----------------------------------------------------------------

  defp match_graphemes_score(tree, [h | t] = search, streak, best, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, _values}, acc -> acc
      {^h, subtree}, acc -> match_graphemes_score(subtree, t, streak + 1, best, acc)
      {_, subtree}, acc -> match_graphemes_score(subtree, search, 0, max(best, streak), acc)
    end)
  end

  defp match_graphemes_score(tree, [], streak, best, acc) do
    collect_values_score(tree, max(streak, best), acc)
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

  # -- Compressed with scoring ------------------------------------------------

  defp match_graphemes_comp_score(tree, [h | t] = search, streak, best, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, _values}, acc ->
        acc

      {^h, subtree}, acc ->
        match_graphemes_comp_score(subtree, t, streak + 1, best, acc)

      {list, subtree}, acc when is_list(list) ->
        match_graphemes_klist_score(list, subtree, search, streak, best, acc)

      {_, subtree}, acc ->
        match_graphemes_comp_score(subtree, search, 0, max(streak, best), acc)
    end)
  end

  defp match_graphemes_comp_score(tree, [], streak, best, acc) do
    collect_values_score(tree, max(streak, best), acc)
  end

  defp match_graphemes_klist_score(tree_keys, subtree, search, streak, best, acc)

  defp match_graphemes_klist_score([h | kt], subtree, [h | t], streak, best, acc) do
    match_graphemes_klist_score(kt, subtree, t, streak + 1, best, acc)
  end

  defp match_graphemes_klist_score([_ | kt], subtree, search, streak, best, acc) do
    match_graphemes_klist_score(kt, subtree, search, 0, max(streak, best), acc)
  end

  # additional clause in scoring code when search graphemes are exhausted when
  # iteraring a compressed key.
  defp match_graphemes_klist_score(_, subtree, [], streak, best, acc) do
    collect_values_score(subtree, max(streak, best), acc)
  end

  defp match_graphemes_klist_score([], subtree, search, streak, best, acc) do
    match_graphemes_comp_score(subtree, search, streak, best, acc)
  end

  # -- Finalizers -------------------------------------------------------------

  defp collect_values(tree, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, values}, acc -> values ++ acc
      {_, subtree}, acc -> collect_values(subtree, acc)
    end)
  end

  defp collect_values_score(tree, best, acc_in) do
    Enum.reduce(tree, acc_in, fn
      {:values, values}, acc -> with_scores(values, best, acc)
      {_, subtree}, acc -> collect_values_score(subtree, best, acc)
    end)
  end

  defp with_scores([v | vs], best, acc) do
    with_scores(vs, best, [{v, best} | acc])
  end

  defp with_scores([], _, acc) do
    acc
  end
end
