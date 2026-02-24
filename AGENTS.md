This repository contains a collection scripts that are used on our CI agents to help build native iOS and Mac apps, Android apps, and cross-platform Electron apps for desktop environments.
The scripts are written in Bash, PowerShell, and Ruby.

Our CI runs on Buildkite infrastructure, using a mix of self-hosted agents (Mac Minis in our data center) and Linux or Windows EC2 instances on AWS.

The scripts are made made available in our CI agents via the Buildkite plugin system.
The scripts in the `bin/` directory are available in the `$PATH` of all our CI jobs that use `a8c-ci-toolkit` in their pipeline steps' `plugins:` attribute.

## Commands

- Lint: `make lint` (runs `shellcheck`, `rubocop`, and `buildkite-plugin-lint` via Docker)
- Test: `make test` (runs `buildkite-plugin-tester` and `rspec` via Docker)
- Both: `make` (default target runs lint then test)

All `make` targets require Docker to be running.

When writing Bash scripts, refer to the rules in:
@.cursor/rules/bash_scripts.mdc

When writing PowerShell scripts, refer to the rules in:
@.cursor/rules/powershell_scripts.mdc
