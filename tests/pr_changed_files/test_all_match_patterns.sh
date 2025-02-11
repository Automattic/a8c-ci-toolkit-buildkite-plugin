#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "--- :git: Testing all-match pattern matching"

# Create test repository
repo_path=$(create_tmp_repo_dir)
trap 'cleanup_git_repo "$repo_path"' EXIT

# Set up environment variables
export BUILDKITE_PULL_REQUEST="123"
export BUILDKITE_PULL_REQUEST_BASE_BRANCH="base"

# Initialize the repository
init_test_repo "$repo_path"

# Create test files (using single quotes to avoid special chars being interpreted by the shell)
mkdir -p docs src/swift
echo "doc1" > 'docs/read me.md'
echo "doc2" > 'docs/guide with spaces.md'
echo "doc3" > 'docs/special\!@*#$chars.md'
git add .
git commit -m "Add doc files"

# [Test] All changes in docs
result=$(pr_changed_files --all-match "docs/*")
assert_output "true" "$result" "Should return true when all changes match patterns"

# [Test] All changes in docs with explicit patterns including spaces and special chars
# Note: we need to escape the '\` and `*` special chars in the pattern to match them literally instead of as special characters
result=$(pr_changed_files --all-match 'docs/read me.md' 'docs/guide with spaces.md' 'docs/special\\!@\*#$chars.md')
assert_output "true" "$result" "Should return true when all changes match patterns with spaces and special chars"

# [Test] All changes in docs with globbing patterns including spaces and special chars
result=$(pr_changed_files --all-match 'docs/read me.md' 'docs/guide with spaces.md' 'docs/special\\!*.md')
assert_output "true" "$result" "Should return true when all changes match patterns with spaces and special chars, even when using globbing"

# [Test] Changes outside pattern
echo "swift" > 'src/swift/main with spaces.swift'
echo "swift" > 'src/swift/special!\@#*$chars.swift'
git add .
git commit -m "Add swift file"

result=$(pr_changed_files --all-match "docs/*")
assert_output "false" "$result" "Should return false when changes exist outside patterns"

# [Test] Multiple patterns, all matching
# Note: we need to escape the '\` and `*` special chars in the pattern to match them literally instead of as special characters
result=$(pr_changed_files --all-match 'docs/*' 'src/swift/main with spaces.swift' 'src/swift/special\!\\@#\*$chars.swift')
assert_output "true" "$result" "Should return true when all changes match multiple patterns"

# [Test] Multiple patterns, all matching, including some using globbing
result=$(pr_changed_files --all-match 'docs/*' 'src/swift/main with spaces.swift' 'src/swift/special*chars.swift')
assert_output "true" "$result" "Should return true when all changes match multiple patterns, including some using globbing"

echo "✅ All-match pattern tests passed"
