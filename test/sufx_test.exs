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
        Enum.map(words, fn word -> {word, {category, String.to_atom(word)}} end)
      end)

    tree = Sufx.tree(data)
    tree |> dbg()

    assert sort([
             {:fruit, :banana},
             {:fruit, :orange},
             {:fruit, :dragonfruit},
             {:location, :"orange county"},
             {:element, :carbon},
             {:element, :radon}
           ]) == sort(Sufx.find_values(tree, "an"))

    :erts_debug.flat_size(tree) |> IO.inspect(label: "tree size")
  end
end
