# Changelog

The format of this document is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- This is a comment, you won't see it when GitHub renders the Markdown file.

When releasing a new version:

1. Update the `## Unreleased` header to `## <version_number>`
2. Remove any empty section (those with `_None._`)
3. Add a new "Unreleased" section for the next iteration, by copy/pasting the following template:

## Unreleased

### Breaking Changes

_None._

### New Features

_None._

### Bug Fixes

_None._

### Internal Changes

_None._

-->

## Unreleased

### Breaking Changes

_None._

### New Features

_None._

### Bug Fixes

_None._

### Internal Changes

_None._

## 5.1.1

### Bug Fixes

- Make `install_gems` account for different C system libraries if `Gemfile.lock` includes `nokogiri` [#149]

## 5.1.0

### New Features

- Add new `comment_with_manifest_diff` command for commenting manifest diff on PRs in Android projects [#164]

## 5.0.0

### Breaking Changes

- `prepare_windows_host_for_node.ps1` has been renamed to `prepare_windows_host_for_app_distribution.ps1` [#144]
- `prepare_windows_host_for_app_distribution.ps1` no longer installs Node.js.
  Clients should use [`nvm-buildkite-plugin`](https://github.com/Automattic/nvm-buildkite-plugin) instead [#144]

### New Features

- Added new command to install Windows 10 SDK on Windows CI machines, `install_windows_10_sdk.ps1` [#144]
- `prepare_windows_host_for_app_distribution.ps1` automatically installs the Windows 10 SDK if version file is found [#144]
- Added new command to run `refreshenv` on Windows preserving the `PATH`, `path_aware_refreshenv.ps1` [#144]

## 4.0.0

### Breaking Changes

- `pr_changed_files` command now uses exit codes by default, with stdout output requiring explicit `--stdout` flag [#151]

## 3.11.0

### New Features

- Add `pr_changed_files` command to detect changes made in a Pull Request [#148]

## 3.10.1

### Bug Fixes

- Do not echo three dashes at the end of restore cache script [#146]

## 3.10.0

### New Features

- Add command to prepare a Windows host to run CI for a Node app [#100]

## 3.9.1

### Bug Fixes

- `Dependency Cache`: Fix Dependency Cache [#138]
- `run_swiftlint`: Error gracefully when `swiftlint_version` is missing in the `.swiftlint.yml` file [#139]

## 3.9.0

### New Features

- `Dependency Cache`: Dependency Cache on CI per Project `[without GRADLE_RO_DEP_CACHE]` [#135]

## 3.8.0

### New Features

- `lint_localized_strings_format` will bypass CocoaPods if a `Podfile.lock` is not found [#136]

## 3.7.1

### Bug Fixes

- Fix logic in our `github_api` helper to auto-detecting the GitHub host [#127] [#128]
- Fix not working SARIF upload on non-PR branches [#124]

## 3.7.0

### New Features

- Add a script for commenting dependencies diff on PRs in Android projects [#120]
- Append summarized list to dependency diff comment [#122]

### Bug Fixes

- Don't require passing owner and repo names to `upload_sarif_to_github` [#121]

## 3.6.2

### Bug Fixes

- Fix passing main branch name when sending sarif file [#118]

## 3.6.1

### Bug Fixes

- Check for $BUILDKITE_PULL_REQUEST = false when uploading sarif file [#116]

### Internal Changes

- Tooling change: Dangermattic setup [#113]

## 3.6.0

### New Features

- Refactor `install_swiftpm_dependencies` to allow specifying `--workspace`/`--project`/`--use-spm` type of project explicitly, and improve implicit/automatic project type detection logic. [#105]
- Introduce a command for uploading .sarif files to GitHub's registry [#111]

### Bug Fixes

- Make sure `install_swiftpm_dependencies` uses the correct `Package.resolved` file (`.xcworkspace` vs `.xcodeproj/project.xcworkspace`). [#105]

## 3.5.1

### Bug Fixes

 - Fix an issue in `annotate_test_failures` when test cases had apostrophes in their name. [#106]

## 3.5.0

### New Features

- Introduce `merge_junit_reports` script. [#103]

## 3.4.2

### Bug Fixes

- Fix `hash_directory` helper, and make it portable (Mac+Linux). [#95]

## 3.4.1

### Bug Fixes

- Fix for the unbound variable error seen on `run_swiftlint`. [#92]

## 3.4.0

### Internal Changes

- Restrict the possible `run_swiftlint` command arguments to "--strict" and "--lenient". [#90]
- Update `swiftlint_version` RegExp to check for top-level node. [#89]

## 3.3.0

### New Features

- Make `publish_private_pod` support `--allow-warnings`. [#86]

### Internal Changes

- Fixed Ruby, RuboCop and RSpec versions on CI. [#88]

## 3.2.2

### Bug Fixes

 - Fix crash in recent update of the `publish_pod` implementation — 2nd attempt. [#85]

## 3.2.1

### Bug Fixes

 - Fix crash in recent update of the `publish_pod` implementation. [#84]

## 3.2.0

### New Features

 - Make `validate_podspec` support `--allow-warnings`, `--sources=…`, `--private`, `--include-podspecs=…` and `--external-podspecs=…` flags that it will forward to the `pod lib lint` call. `--include-podspecs=*.podspec` is also now added by default if not provided explicitly. [#82]
 - Make `publish_pod` support `--allow-warnings` and `--synchronous` flags that it will forward to the `pod trunk push` call. This is especially useful for repos containing multiple, co-dependant podspecs to publish at the same time, to avoid issues with CDN propagation delays. [#82]

## 3.1.0

### New Features

- Added `run_swiftlint` command. It will use the project's SwiftLint version defined in `.swiftlint.yml` property `swiftlint_version` to run the right SwiftLint version via Docker, reporting the warnings/errors as Buildkite annotations.

## 3.0.1

### Internal Changes

- Fix an issue where `validate_podspec` and `publish_pod` fail on Xcode 15.0.1 if the pod has a dependency which targets iOS version older than 13. [#78]

## 3.0.0

### Breaking Changes

- `nvm_install` utility is removed. See [MIGRATION.md](./MIGRATION.md#from-200-to-300) for details. [#73]

### Bug Fixes

 - Fix issue in `annotate_test_failures` where the error details' XML node could sometimes be `nil`. [#76]
 - Make `install_swiftpm_dependencies` use `-onlyUsePackageVersionsFromResolvedFile` flag, to prevent `Package.resolved` from being modified on CI. [#75]

### Internal Changes

- Refine message in `annotate_test_failures` when configuration for optional Slack reporting is missing. [#74]

## 2.18.2

### Bug Fixes

- Ensure that `install_gems` doesn't restore a macOS cache on Linux build machines. [#69]
- Ensure that `install_gems` uses the correct ruby version in its `CACHE_KEY` in all cases. [#70]

## 2.18.1

### Bug Fixes

- Fix an issue with `annotate_test_failures` on CI steps that are using the `parallelism` attribute. [#67]

## 2.18.0

### Bug Fixes

- `annotate_test_failures` no longer prints an empty `<code>` box when reporting a `failure` with no extra `details`. [#63]
- `annotate_test_failures` is now able to remove annotations on successful step retry _even if_ the step label contains special characters. [#65]

## 2.17.0

### New Features

- When `install_cocoapods` fails because `Podfile.lock` changed in CI, it now prints a diff of the changes. [#59]
- Update `annotate_test_failures` to be able to send Slack Notification when there are failures. [#60]

### Bug Fixes

- Fix the `annotate_test_failures` to include test cases with error nodes in the failures list. [#58]

## 2.16.0

### New Features

- Add a new `github_api` utlity to make API requests to GitHub.com or Github Enterprise instances. [#51]
- Extend the `comment_on_pr` utility to update or delete the existing comment. [#51]

### Bug Fixes

- Prevent `annotate_test_failures` to print a misleading red error message when trying to remove previous annotation. [#50]

### Internal Changes

- Added this changelog file. [#49]
- Re-implement the `comment_on_pr` utility to use `curl` instead of `gh`. [#51]
