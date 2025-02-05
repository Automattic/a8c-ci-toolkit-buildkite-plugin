#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "--- :git: Testing includes pattern matching"

# Create test repository
repo_path=$(create_tmp_repo_dir)
trap 'cleanup_git_repo "$repo_path"' EXIT

# Set up environment variables
export BUILDKITE_PULL_REQUEST="123"
export BUILDKITE_PULL_REQUEST_BASE_BRANCH="base"

# Initialize the repository
init_test_repo "$repo_path"

# Create test files
mkdir -p docs src/swift src/ruby
echo "doc" > "docs/read me.md"
echo "doc" > "docs/special\!\@\#\$chars.md"
echo "swift" > src/swift/main.swift
echo "ruby" > src/ruby/main.rb
git add .
git commit -m "Add test files"

# [Test] Match specific extension
result=$(pr_changed_files --includes "*.swift")
assert_output "true" "$result" "Should match .swift files"

# [Test] Match multiple patterns
result=$(pr_changed_files --includes "docs/*.md" "*.rb")
assert_output "true" "$result" "Should match multiple patterns"

# [Test] Match files with spaces and special characters
result=$(pr_changed_files --includes "docs/read me.md" "docs/special\!\@\#\$chars.md")
assert_output "true" "$result" "Should match files with spaces and special characters"

# [Test] No matches
result=$(pr_changed_files --includes "*.js")
assert_output "false" "$result" "Should not match non-existent patterns"

# [Test] Directory pattern
result=$(pr_changed_files --includes "docs/*")
assert_output "true" "$result" "Should match directory patterns"

# [Test] Exact pattern matching
echo "swiftfile" > swiftfile.txt
git add swiftfile.txt
git commit -m "Add file with swift in name"

result=$(pr_changed_files --includes "*.swift")
assert_output "true" "$result" "Should only match exact patterns"

echo "✅ Includes pattern tests passed"
