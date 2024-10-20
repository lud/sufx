defmodule Helper do
  import ExUnit.Assertions

  def fake_word do
    :erlang.unique_integer()
    |> Integer.to_string()
    |> Base.encode64()
  end

  def random_score do
    Enum.random(1..999_999)
  end

  # return results with unique scorings. This is for not having to have
  # different orderings for items with a common scoring. We do not want to
  # handle this case.
  def fake_results(n) do
    Enum.zip(
      Stream.repeatedly(&fake_word/0),
      Enum.shuffle(1..n)
    )
  end

  def assert_same_sort(a, b), do: assert_same_sort(a, b, 0)

  def assert_same_sort([h | ta], [h | tb], pos), do: assert_same_sort(ta, tb, pos + 1)

  def assert_same_sort([_ | _] = a, [_ | _] = b, pos) do
    peek_a = Enum.take(a, 5)
    peek_b = Enum.take(b, 5)

    flunk("""
    different sorting returned at position: #{pos}

    A
    #{inspect(peek_a, pretty: true)}

    B
    #{inspect(peek_b, pretty: true)}
    """)
  end

  def assert_same_sort([], [], _) do
    true
  end
end

inputs = %{
  "small" => Helper.fake_results(10),
  # Medium is what we should optimize for
  "medium" => Helper.fake_results(1000),
  "large" => Helper.fake_results(100_000)
}

algos = %{
  "sortby" => fn list -> Enum.sort_by(list, &elem(&1, 1), :desc) end,
  "keysort" => fn list -> List.keysort(list, 1, :desc) end,
  "keysort_rev" => fn list -> Enum.reverse(List.keysort(list, 1, :asc)) end,
  "keysort_rev_raw" => fn list -> :lists.reverse(:lists.keysort(2, list)) end
}

# verify algorithms
for {_, input} <- inputs do
  sorts = Enum.map(algos, fn {_, algo} -> algo.(input) end)

  # check Helper.fake_results, all generated scorings are unique, because our
  # algos do not yield the same result for items with a common scoring. This is
  # fine for us, so we avoid having common scorings for the benchmark.
  Enum.reduce(sorts, fn sort, prev ->
    Helper.assert_same_sort(prev, sort)
    sort
  end)
end

IO.puts("All algos OK")

Benchee.run(
  algos,
  pre_check: true,
  warmup: 1,
  time: 2,
  memory_time: 1,
  inputs: inputs
)
