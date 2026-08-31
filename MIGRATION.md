# Migration Instructions for Major Releases

## From 6.0.0 to 7.0.0

* The `git-conceal-unlock` helper has been removed.
  Use [`a8c-secrets`](https://github.com/Automattic/a8c-secrets) instead, installing it with `install_a8c-secrets_binary`.
* All the CocoaPods commands have been removed: `build_and_test_pod`, `cache_cocoapods`, `cache_cocoapods_specs_repos`, `install_cocoapods`, `lint_pod`, `patch-cocoapods`, `publish_pod`, `publish_private_pod`, `slack_notify_pod_published`, `validate_podfile_lock`, and `validate_podspec`.
  This plugin offers no replacement for them, so pipelines that still build or publish with CocoaPods need to stay pinned to a `6.x` version.
* `lint_localized_strings_format` no longer runs `install_cocoapods` when it finds a `Podfile.lock`.
  Install the pods before calling it if the strings generation depends on them.

## From 5.0.0 to 6.0.0

Breaking changes in this release only affect pipelines building on Windows agents:
* The `prepare_windows_host_for_app_distribution.ps1` script has been removed, as its functionality is now pre-provisioned in our custom Windows AMI. Remove any calls to this script from your pipeline steps.
* Scripts to install Python and Windows 10 SDK have been removed, as they are now pre-installed in our custom Windows AMI. Remove any calls to these scripts from your pipeline steps.
* The script to refresh the environment after a Chocolatey install has been removed, as this functionality is now available in the custom Windows AMI. Remove any calls to this script from your pipeline steps.

## From 4.0.0 to 5.0.0

* Use `prepare_windows_host_for_app_distribution.ps1` instead of `prepare_windows_host_for_node.ps1`.
* This plugin no longer sets up Node.js in Windows clients, us use [`nvm-buildkite-plugin`](https://github.com/Automattic/nvm-buildkite-plugin) instead.

## From 3.0.0 to 4.0.0

* In 4.0.0, the `pr_changed_files` command uses exit codes by default.
  To flag to replicate the previous behavior with stdout output, use the `--stdout`.

## From 2.0.0 to 3.0.0

* The `nvm_install` utility has been removed in 3.0.0. Here are the detailed migration steps:
  - Remove all `nvm_install` calls from pipeline steps.
  - Add [nvm-buildkite-plugin](https://github.com/Automattic/nvm-buildkite-plugin#example) to the pipeline step yaml.
  - (Optional) Configure the `version` option to be the node.js version that's required by the pipeline step. The `.nvmrc` file will be used if it's not set.
