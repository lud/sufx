# Sufx

<!-- rdmx :badges
    hexpm         : "sufx?color=4e2a8e"
    github_action : "lud/sufx/elixir.yaml?label=CI&branch=main"
    license       : sufx
    -->
[![hex.pm Version](https://img.shields.io/hexpm/v/sufx?color=4e2a8e)](https://hex.pm/packages/sufx)
[![Build Status](https://img.shields.io/github/actions/workflow/status/lud/sufx/elixir.yaml?label=CI&branch=main)](https://github.com/lud/sufx/actions/workflows/elixir.yaml?query=branch%3Amain)
[![License](https://img.shields.io/hexpm/l/sufx.svg)](https://hex.pm/packages/sufx)
<!-- rdmx /:badges -->

This library provides simple fuzzy matching of strings given a search pattern.
Patterns are a suite of characters without any special meaning, simply put, a
string.

This resembles VS Code fuzzy finder, with a very basic scoring algorithm.

The implemenation is based on a suffix tree, though this library is not a
generic suffix tree or suffix trie implementation.

## Installation

The package can be installed by adding `sufx` to your list of dependencies in
`mix.exs`:

<!-- rdmx :app_dep vsn:$app_vsn -->
```elixir
def deps do
  [
    {:sufx, "~> 0.1"},
  ]
end
```
<!-- rdmx /:app_dep -->

## Documentation

The documentation is available on [HexDocs](https://hexdocs.pm/sufx).

## Example

A tree is defined by a map of tokens, where each key is a string and each value
any term of your chosing. Here for instance we are building a tree to help find
general domain topics. The values are composed of a domain (_programming_,
_physics_, …) and the topic name. The search will be performed on the topic
names so we use them for keys as well.

Once the tree is built, we can search, for instance with the `"alg"` string.

<!-- rdmx :section name:search format:true -->
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

Sufx.search(tree, "alg")
```
<!-- rdmx /:section -->

The code above returns the following results:

<!-- rdmx :eval section:search -->
```elixir
[physics: "wavelength", philosophy: "allegory", programming: "algorithm"]
```
<!-- rdmx /:eval -->

The matches were computed like so:

* w**a**ve**l**en**g**th
* **al**le**g**ory
* **alg**orithm

The library supports a simplistic scoring mechanism based on the length of the
matched patterns. With the following code:

<!-- rdmx :section name:search_score format:true -->
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

tree
|> Sufx.search_score("alg")
|> Sufx.sort_by_score()
```
<!-- rdmx /:section -->

We would get the following results:

<!-- rdmx :eval section:search_score -->
```elixir
[
  {{:programming, "algorithm"}, 3},
  {{:philosophy, "allegory"}, 2},
  {{:physics, "wavelength"}, 1}
]
```
<!-- rdmx /:eval -->

When building the tree, the key does not have to be part of the value. For
instance to match user posts in a database, where the user has posts like
these:

<!-- rdmx :section name:documents format:true -->
```elixir
documents = [
  %{id: 1001, title: "Collectible card game are great!"},
  %{id: 1002, title: "Discussion on suffixes"},
  %{id: 1003, title: "Cats for the greater good"},
  %{id: 1004, title: "Cats considered harmul!"}
]

tree =
  documents
  |> Enum.reduce(Sufx.new(), fn post, tree ->
    Sufx.insert(tree, post.title, post.id)
  end)
  |> Sufx.compress()

Sufx.search_score(tree, "cgg")
```
<!-- rdmx /:section -->

As we did not include the searchable strings in our values, but just the post
IDs, this is what we expect:

<!-- rdmx :eval section:documents -->
```elixir
[{1001, 1}, {1003, 1}]
```
<!-- rdmx /:eval -->

And `Sufx.search_score(tree, "CCG")` would yield `[{1001, 1}]`.
