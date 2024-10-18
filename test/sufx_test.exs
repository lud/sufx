defmodule SufxTest do
  use ExUnit.Case
  import Enum, only: [sort: 1]

  test "normalize graphemes" do
    assert String.graphemes("elixir is cool") ==
             Sufx.to_graphemes("Elixir\u0085  \n\tis\u00A0cool")
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
        Enum.map(words, fn word -> {word, {category, word}} end)
      end)

    tree = Sufx.tree(data)

    assert sort(
             fruit: "banana",
             fruit: "orange",
             fruit: "dragonfruit",
             location: "orange county",
             element: "carbon",
             element: "radon"
           ) == sort(Sufx.find_values(tree, "an"))
  end

  test "create from words - optimize" do
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
        Enum.map(words, fn word -> {word, {category, word}} end)
      end)

    tree = Sufx.tree(data)
    tree = Sufx.optimize(tree)

    assert sort(
             fruit: "banana",
             fruit: "orange",
             fruit: "dragonfruit",
             location: "orange county",
             element: "carbon",
             element: "radon"
           ) == sort(Sufx.find_values(tree, "an"))
  end
end
