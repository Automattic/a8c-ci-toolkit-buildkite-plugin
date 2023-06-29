# Changelog

The format of this document is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- This is a comment, you won't see it when GitHub renders the Markdown file.

When releasing a new version:

1. Remove any empty section (those with `_None._`)
2. Update the `## Unreleased` header to `## <version_number>`
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

## 2.18.0

### Bug Fixes

- `annotate_test_failures` no longer prints an empty `<code>` box when reporting a `failure` with no extra `details`. [#63]
- `annotate_test_failures` is now able to remove annotations on successful step retry _even if_ the step label contains special characters. [#65]

## 2.17.0

### New Features

- When `install_cocoapods` fails because `Podfile.lock` changed in CI, it now prints a diff of the changes [#59]
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
