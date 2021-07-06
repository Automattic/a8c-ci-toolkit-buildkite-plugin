#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

@test "Exposes 'hash_file' command" {
  source "$PWD/hooks/environment"
  which hash_file > /dev/null
  return $?
}

@test "Exposes 'hash_directory' command" {
  source "$PWD/hooks/environment"
  which hash_directory > /dev/null
  return $?
}

@test "Exposes 'save_cache' command" {
  source "$PWD/hooks/environment"
  which save_cache > /dev/null
  return $?
}

@test "Exposes 'restore_cache' command" {
  source "$PWD/hooks/environment"
  which restore_cache > /dev/null
  return $?
}
