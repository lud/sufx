source_data =
  "benchmarks/english-3000.txt"
  |> File.read!()
  |> String.split("\n")

sufx = Enum.reduce(source_data, Sufx.new(), fn word, sufx -> Sufx.insert(sufx, word, word) end)

compressed_sufx = Sufx.compress(sufx)

# Verify that all functions return the same result, possibly in different order
check_same_results = fn search ->
  import ExUnit.Assertions
  a = Sufx.find_values(sufx, search)
  b = Sufx.find_values(sufx, search)
  c = Sufx.find_values(Sufx.compress(sufx), search)
  assert Enum.sort(a) == Enum.sort(b)
  assert Enum.sort(a) == Enum.sort(c)
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

# length(Sufx.find_values(sufx, "aoe") |> dbg())  |> dbg()

Benchee.run(
  %{
    "nocompress" => fn search -> Sufx.find_values(sufx, search) end,
    "compressed" => fn search -> Sufx.find_values(compressed_sufx, search) end
  },
  pre_check: true,
  warmup: 1,
  time: 2,
  memory_time: 1,
  inputs: %{
    "input_129" => input_129,
    "input_22" => input_22,
    "input_26" => input_26,
    "input_97" => input_97,
    "input_none" => input_none,
    "input_one" => input_one
  }
)
