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

- Prevent `annotate_test_failures` to print a misleading red error message when trying to remove previous annotation. [#50]

### Internal Changes

- Added this changelog file. [#49]
- Re-implement the `comment_on_pr` utility to use `curl` instead of `gh`. [#51]
- Extend the `comment_on_pr` utility to update or delete the existing comment. [#51]
