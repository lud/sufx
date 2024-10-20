# Sufx

This library provides simple fuzzy matching of strings given a search pattern.
Patterns are a suite of characters without any special meaning, simply put, a
string.

This resembles VS Code fuzzy finder, with a very basic scoring algorithm.

The implemenation is based on a suffix tree, though this library is not a
generic suffix tree or suffix trie implementation.

## Example

A tree is defined by a map of tokens, where each key is a string and each value
any term of your chosing. Here for instance we are building a tree to help find
general domain topics. The values are composed of a domain (_programming_,
_physics_, …) and the topic name. The search will be performed on the topic
names so we use them for keys.

```elixir
tree =
  %{
    "algorithm" => {:programming, "algorithm"},
    "wavelength" => {:physics, "wavelength"},
    "allegory" => {:philosophy, "allegory"},
    "novel" => {:litterature, "novel"}
  }
  |> Sufx.new()
  |> Sufx.compress()
```

Now the tree is ready to use, we can search, for instance with the `"alg"`
string.

```elixir
results = Sufx.search(tree, "alg")
IO.inspect(results, label: "results")
```

The code above would print the following results:

```
results: [
  physics: "wavelength",
  philosophy: "allegory",
  programming: "algorithm"
]
```

The matches were computed like so:

* w**a**ve**l**en**g**th
* **al**le**g**ory
* **alg**orithm

The library supports a simplistic scoring mechanism based on the length of the matched patterns. With the following code:

```elixir
results =
  tree
  |> Sufx.search_score("alg")
  |> Sufx.sort_by_score()

IO.inspect(results, label: "results")
```

We would get the following results:

```
results: [
  {{:programming, "algorithm"}, 3},
  {{:philosophy, "allegory"}, 2},
  {{:physics, "wavelength"}, 1}
]
```

When building the tree, the key does not have to be part of the value. For instance to match user posts in a database, where the user has posts like these:

```elixir
documents =
  [
    %{id: 1001, title: "Collectible card game are great!"},
    %{id: 1002, title: "Discussion on suffixes"},
    %{id: 1003, title: "Cats for the greater good"},
    %{id: 1004, title: "Cats considered harmul!"}
  ]
```

A tree could be built and searched like so:

```elixir
tree =
  documents
  |> Enum.reduce(Sufx.new(), fn post, tree ->
    Sufx.insert(tree, post.title, post.id)
  end)
  |> Sufx.compress()

results = Sufx.search_score(tree, "cgg")
```

As we did not include the searchable strings in our values, but just the post IDs, this is what we expect:

```
results: [{1001, 1}, {1003, 1}]
```

And `Sufx.search_score(tree, "CCG")` would yield `[{1001, 1}]`.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `sufx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sufx, "~> 0.1.0"},
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/sufx>.

