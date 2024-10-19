source_data =
  "benchmarks/english-3000.txt"
  |> File.read!()
  |> String.split("\n")

{most_common_grapheme, _} =
  source_data
  |> Enum.map(&(&1 |> Sufx.to_graphemes() |> Enum.frequencies()))
  |> Enum.reduce(&Map.merge(&1, &2, fn _, a, b -> a + b end))
  |> Map.to_list()
  |> Enum.sort_by(&elem(&1, 1), :desc)
  |> hd()

sufx = Enum.reduce(source_data, Sufx.new(), fn word, sufx -> Sufx.insert(sufx, word, word) end)

compressed_sufx = Sufx.compress(sufx)

without_ranks = fn list ->
  # Do not accept ranking of zero
  Enum.map(list, fn {v, rank} when rank > 0 -> v end)
end

# Verify that all functions return the same result, possibly in different order
check_same_results = fn search ->
  import ExUnit.Assertions
  a = Sufx.search(sufx, search)
  b = Sufx.search(sufx, search)
  c = Sufx.search(compressed_sufx, search)
  # ranked
  d = Sufx.search_ranked(sufx, search)
  e = Sufx.search_ranked(compressed_sufx, search)
  assert Enum.sort(a) == Enum.sort(b)
  assert Enum.sort(a) == Enum.sort(c)
  assert Enum.sort(a) == Enum.sort(without_ranks.(d))
  assert Enum.sort(a) == Enum.sort(without_ranks.(e))
  assert Enum.sort(d) == Enum.sort(e)
  a
end

# Inputs

input_none = "axo"
[] = check_same_results.(input_none)

input_one = "arx"
["approximately"] = check_same_results.(input_one)

# aoe is a rare trigram
input_22 = "aoe"
found_22 = check_same_results.(input_22)
22 = length(found_22)

input_26 = "bet"
found_26 = check_same_results.(input_26)
26 = length(found_26)

# this one has a lot of words finishing with "ing"
input_97 = "ing"
found_97 = check_same_results.(input_97)
97 = length(found_97)

# lots of words starting with pre
input_129 = "pre"
found_129 = check_same_results.(input_129)
129 = length(found_129)

# length(Sufx.search(sufx, "aoe") |> dbg())  |> dbg()

Benchee.run(
  %{
    "nocompress" => fn search -> Sufx.search(sufx, search) end,
    "rankd/nocp" => fn search -> Sufx.search_ranked(sufx, search) end,
    "compressed" => fn search -> Sufx.search(compressed_sufx, search) end,
    "rankd/comp" => fn search -> Sufx.search_ranked(compressed_sufx, search) end
  },
  pre_check: true,
  warmup: 1,
  time: 2,
  memory_time: 0,
  inputs: %{
    "input_129" => input_129,
    "input_22" => input_22,
    "input_26" => input_26,
    "input_97" => input_97,
    "input_none" => input_none,
    "input_one" => input_one,
    "most_common_grapheme" => most_common_grapheme
  }
)
