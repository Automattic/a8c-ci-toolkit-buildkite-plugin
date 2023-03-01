#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

fail() {
  echo "Failure: $1"
  exit 1
}

@test "Exposes all commands in bin/" {
  source "$PWD/hooks/environment"
  for f in "bin"/*; do
    cmd=$(basename "$f")
    which "$cmd" > /dev/null || fail "$cmd is not exposed to \$PATH"
  done
}
