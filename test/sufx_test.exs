defmodule SufxTest do
  use ExUnit.Case
  import Enum, only: [sort: 1]

  test "normalize graphemes" do
    assert String.graphemes("elixir is cool") ==
             Sufx.to_graphemes("Elixir\u0085  \n\tis\u00A0cool")
  end

  test "search for empty string will always return nothing" do
    tree = Sufx.new([{"some", :value}])
    assert [] = Sufx.search(tree, "")
    assert [] = Sufx.search_ranked(tree, "")
  end

  test "create from words" do
    data =
      [
        fruit: [
          "banana",
          "apple",
          "apricot",
          "orange",
          "dragonfruit"
        ],
        location: [
          "orange county",
          "general"
        ],
        profession: [
          "artist",
          "programmer",
          "engineer",
          "scientist"
        ],
        element: [
          "carbon",
          "radon",
          "oxygen"
        ]
      ]
      |> Enum.flat_map(fn {category, words} ->
        Enum.map(words, fn word -> {word, {category, String.to_atom(word)}} end)
      end)

    tree = Sufx.new(data)

    assert sort(
             fruit: :banana,
             fruit: :orange,
             fruit: :dragonfruit,
             location: :"orange county",
             element: :carbon,
             element: :radon
           ) == sort(Sufx.search(tree, "an"))
  end

  test "create from words - compress" do
    data =
      [
        special: ["", ""],
        fruit: [
          "banana",
          "apple",
          "apricot",
          "orange",
          "dragonfruit"
        ],
        location: [
          "orange county",
          "general"
        ],
        profession: [
          "artist",
          "programmer",
          "engineer",
          "scientist"
        ],
        element: [
          "carbon",
          "radon",
          "oxygen"
        ]
      ]
      |> Enum.flat_map(fn {category, words} ->
        Enum.map(words, fn word -> {word, {category, String.to_atom(word)}} end)
      end)

    tree = Sufx.new(data)
    tree = Sufx.compress(tree)
    assert true == tree.compressed?

    assert sort(
             fruit: :banana,
             fruit: :orange,
             fruit: :dragonfruit,
             location: :"orange county",
             element: :carbon,
             element: :radon
           ) == sort(Sufx.search(tree, "an"))
  end

  # returns a compressed tree from words where the value is the word itself
  defp compressed_words(words) do
    words
    |> uncompressed_words()
    |> Sufx.compress()
  end

  # returns a tree from words where the value is the word itself
  defp uncompressed_words(words) do
    words
    |> Enum.map(&{&1, &1})
    |> Sufx.new()
  end

  test "basic ranking" do
    # Ranking is done by counting the highest streak of matches we find.
    #
    # * "an" matches "banana" with a score of 2
    # * "an" matches "orange" with a score of 2
    # * "cas" matches "outcast" with a score of 3
    # * "cas" matches "crates" with a score of 1
    tree = compressed_words(~w(banana orange outcast crates))

    assert [{"banana", 2}, {"orange", 2}] = sort(Sufx.search_ranked(tree, "an"))
  end

  test "first/last letter score is counted" do
    tree = compressed_words(~w(banjo orange ban))

    assert [{"banjo", 1}, {"orange", 1}] = sort(Sufx.search_ranked(tree, "o"))
    assert [{"ban", 2}, {"banjo", 2}, _] = sort(Sufx.search_ranked(tree, "an"))
  end

  test "ranking subtrees" do
    tree = compressed_words(~w(banana banjo orange brain))

    assert [{"banana", 3}, {"banjo", 3}, {"brain", 1}] =
             sort(Sufx.search_ranked(tree, "ban"))
  end

  test "no rank of zero" do
    # When benchmarking we found a bug where "between" would be ranked zero with
    # search "bet".
    #
    # We could isolate the bug in this smaller version of the tree.
    tree =
      "benchmarks/english-3000.txt"
      |> File.read!()
      |> String.split("\n")
      |> Enum.sort()
      |> Enum.drop_while(&(&1 < "best"))
      |> Enum.take_while(&(&1 <= "between"))
      |> compressed_words()

    assert {"between", 3} =
             tree
             |> Sufx.search_ranked("bet")
             |> List.keyfind("between", 0)
  end

  test "compare ranking compressed/not-compressed" do
    runcase = fn words, search ->
      tree = uncompressed_words(words)
      comp_tree = Sufx.compress(tree)
      ranks = Sufx.search_ranked(tree, search)
      comp_ranks = Sufx.search_ranked(comp_tree, search)
      assert ranks == comp_ranks
      ranks
    end

    runcase.(["orange", "banana"], "an")
    runcase.(["joe", "robert", "william"], "")
    runcase.(["joe", "robert", "william"], "oe")
    runcase.(["ananana", "nananan", "xoan"], "an")
    runcase.(["ananana", "nananan", "xoan"], "nan")
    runcase.(["aaa", "a"], "a")
    runcase.(["aaaa", "axaxa"], "aa")
    runcase.(["qwerty", "azerty"], "erty")
    runcase.(["aaaxxxy", "aaaoooy"], "aao")
    runcase.(["aaaxxxy", "aaaoooy"], "aax")
    runcase.(["aaaxxxy", "aaaoooy"], "aay")
    runcase.(["aaaxxxy", "aaaoooy"], "aay")
  end

  test "sort_by_rank" do
    assert [{"a", 100}, {"n", 50}, {"z", 3}] =
             Sufx.sort_by_rank([{"n", 50}, {"z", 3}, {"a", 100}])
  end

  test "inserting in compressed tree" do
    tree = compressed_words(~w(banana orange))

    assert_raise ArgumentError, fn ->
      Sufx.insert(tree, "banjo", "banjo") |> dbg()
    end

    # Not supported so far
    # refute is_map_key(tree.tree, "b")
    # assert is_map_key(tree.tree, ["b", "a", "n"])
    # assert ["banana", "banjo"] = sort(Sufx.search(tree, "ban") )
  end
end
