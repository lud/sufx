test:
  mix test

_git_status:
  git status

format:
  mix format

credo:
  mix credo --strict --all

dialyzer:
  mix dialyzer

sample: format
  mix run tmp/sample.exs

check: format test credo dialyzer _git_status