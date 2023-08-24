# Migration Instructions for Major Releases

## From 2.0.0 to 3.0.0

* The `nvm_install` utility has been removed in 3.0.0. Here are the detailed migration steps:
  - Remove all `nvm_install` calls from pipeline steps.
  - Add [nvm-buildkite-plugin](https://github.com/Automattic/nvm-buildkite-plugin#example) to the pipeline step yaml.
  - (Optional) Configure the `version` option to be the node.js version that's required by the pipeline step. The `.nvmrc` file will be used if it's not set.
