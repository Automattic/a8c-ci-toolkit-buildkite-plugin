#!/bin/bash -u

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "--- :git: Testing any-match pattern matching"

# Create test repository
repo_path=$(create_tmp_repo_dir)
trap 'cleanup_git_repo "$repo_path"' EXIT

# Set up environment variables
export BUILDKITE_PULL_REQUEST="123"
export BUILDKITE_PULL_REQUEST_BASE_BRANCH="base"

# Initialize the repository
init_test_repo "$repo_path"

# Create test files (using single quotes to avoid special chars being interpreted by the shell)
mkdir -p docs src/swift src/ruby
echo "doc" > 'docs/read me.md'
echo "doc" > 'docs/special!@*#$chars.md'
echo "swift" > 'src/swift/main.swift'
echo "ruby" > 'src/ruby/main.rb'
git add .
git commit -m "Add test files"

# [Test] Match specific extension - check output string
output=$(pr_changed_files --any-match '*.swift')
result=$?
assert_return_code 0 $result "Should match .swift files"
assert_output "true" "$output" "Should output 'true' string when matching .swift files"

# [Test] Match multiple patterns
pr_changed_files --any-match 'docs/*.md' '*.rb'
result=$?
assert_return_code 0 $result "Should match multiple patterns"

# [Test] Match files with spaces and special characters
pr_changed_files --any-match 'docs/read me.md' 'docs/special!@\*#$chars.md'
result=$?
assert_return_code 0 $result "Should match files with spaces and special characters"

# [Test] Match files with spaces and special characters, even when using globbing
pr_changed_files --any-match 'docs/read me.md' 'docs/special*chars.md'
result=$?
assert_return_code 0 $result "Should match files with spaces and special characters, even when using globbing"

# [Test] No matches - check output string
output=$(pr_changed_files --any-match '*.js')
result=$?
assert_return_code 1 $result "Should not match non-existent patterns"
assert_output "false" "$output" "Should output 'false' string when no patterns match"

# [Test] Directory pattern
pr_changed_files --any-match 'docs/*'
result=$?
assert_return_code 0 $result "Should match directory patterns"

# [Test] Exact pattern matching
echo "swiftfile" > swiftfile.txt
git add swiftfile.txt
git commit -m "Add file with swift in name"

pr_changed_files --any-match '*.swift'
result=$?
assert_return_code 0 $result "Should only match exact patterns"

echo "✅ Any-match pattern tests passed"
