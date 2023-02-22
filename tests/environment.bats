#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

@test "Exposes all commands in bin/" {
  source "$PWD/hooks/environment"
  for cmd in "$PWD/bin"/*; do
    which "$(basename "$cmd")" > /dev/null
  done
}

@test "Ensure all commands in bin/ are executable" {
  for cmd in "$PWD/bin"/*; do
    [ -x "$cmd" ]
  done
}

