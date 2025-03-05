# Migration Instructions for Major Releases

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
