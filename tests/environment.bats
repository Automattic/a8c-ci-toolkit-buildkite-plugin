#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

@test "Exposes 'add_host_to_ssh_known_hosts' command" {
  source "$PWD/hooks/environment"
  which add_host_to_ssh_known_hosts > /dev/null
  return $?
}

@test "Exposes 'add_ssh_key_to_agent' command" {
  source "$PWD/hooks/environment"
  which add_ssh_key_to_agent > /dev/null
  return $?
}

@test "Exposes 'annotate_test_failures' command" {
  source "$PWD/hooks/environment"
  which annotate_test_failures > /dev/null
  return $?
}

@test "Exposes 'build_and_test_pod' command" {
  source "$PWD/hooks/environment"
  which build_and_test_pod > /dev/null
  return $?
}

@test "Exposes 'cache_cocoapods' command" {
  source "$PWD/hooks/environment"
  which cache_cocoapods > /dev/null
  return $?
}

@test "Exposes 'cache_cocoapods_specs_repos' command" {
  source "$PWD/hooks/environment"
  which cache_cocoapods_specs_repos > /dev/null
  return $?
}

@test "Exposes 'cache_repo' command" {
  source "$PWD/hooks/environment"
  which cache_repo > /dev/null
  return $?
}

@test "Exposes 'comment_on_pr' command" {
  source "$PWD/hooks/environment"
  which comment_on_pr > /dev/null
  return $?
}

@test "Exposes 'download_artifact' command" {
  source "$PWD/hooks/environment"
  which download_artifact > /dev/null
  return $?
}

@test "Exposes 'dump_ruby_env_info' command" {
  source "$PWD/hooks/environment"
  which dump_ruby_env_info > /dev/null
  return $?
}

@test "Exposes 'hash_directory' command" {
  source "$PWD/hooks/environment"
  which hash_directory > /dev/null
  return $?
}

@test "Exposes 'hash_file' command" {
  source "$PWD/hooks/environment"
  which hash_file > /dev/null
  return $?
}

@test "Exposes 'install_cocoapods' command" {
  source "$PWD/hooks/environment"
  which install_cocoapods > /dev/null
  return $?
}

@test "Exposes 'install_gems' command" {
  source "$PWD/hooks/environment"
  which install_gems > /dev/null
  return $?
}

@test "Exposes 'install_npm_packages' command" {
  source "$PWD/hooks/environment"
  which install_npm_packages > /dev/null
  return $?
}

@test "Exposes 'install_swiftpm_dependencies' command" {
  source "$PWD/hooks/environment"
  which install_swiftpm_dependencies > /dev/null
  return $?
}

@test "Exposes 'lint_localized_strings_format' command" {
  source "$PWD/hooks/environment"
  which lint_localized_strings_format > /dev/null
  return $?
}

@test "Exposes 'lint_pod' command" {
  source "$PWD/hooks/environment"
  which lint_pod > /dev/null
  return $?
}

@test "Exposes 'nvm_install' command" {
  source "$PWD/hooks/environment"
  which nvm_install > /dev/null
  return $?
}

@test "Exposes 'prepare_to_publish_to_s3_params' command" {
  source "$PWD/hooks/environment"
  which prepare_to_publish_to_s3_params > /dev/null
  return $?
}

@test "Exposes 'publish_pod' command" {
  source "$PWD/hooks/environment"
  which publish_pod > /dev/null
  return $?
}

@test "Exposes 'publish_private_pod' command" {
  source "$PWD/hooks/environment"
  which publish_private_pod > /dev/null
  return $?
}

@test "Exposes 'restore_cache' command" {
  source "$PWD/hooks/environment"
  which restore_cache > /dev/null
  return $?
}

@test "Exposes 'restore_gradle_dependency_cache' command" {
  source "$PWD/hooks/environment"
  which restore_gradle_dependency_cache > /dev/null
  return $?
}

@test "Exposes 'save_cache' command" {
  source "$PWD/hooks/environment"
  which save_cache > /dev/null
  return $?
}

@test "Exposes 'save_gradle_dependency_cache' command" {
  source "$PWD/hooks/environment"
  which save_gradle_dependency_cache > /dev/null
  return $?
}

@test "Exposes 'slack_notify_pod_published' command" {
  source "$PWD/hooks/environment"
  which slack_notify_pod_published > /dev/null
  return $?
}

@test "Exposes 'upload_artifact' command" {
  source "$PWD/hooks/environment"
  which upload_artifact > /dev/null
  return $?
}

@test "Exposes 'upload_buildkite_test_analytics_junit' command" {
  source "$PWD/hooks/environment"
  which upload_buildkite_test_analytics_junit > /dev/null
  return $?
}

@test "Exposes 'validate_gemfile_lock' command" {
  source "$PWD/hooks/environment"
  which validate_gemfile_lock > /dev/null
  return $?
}

@test "Exposes 'validate_gradle_wrapper' command" {
  source "$PWD/hooks/environment"
  which validate_gradle_wrapper > /dev/null
  return $?
}

@test "Exposes 'validate_podfile_lock' command" {
  source "$PWD/hooks/environment"
  which validate_podfile_lock > /dev/null
  return $?
}

@test "Exposes 'validate_podspec' command" {
  source "$PWD/hooks/environment"
  which validate_podspec > /dev/null
  return $?
}

@test "Exposes 'validate_swift_package' command" {
  source "$PWD/hooks/environment"
  which validate_swift_package > /dev/null
  return $?
}
