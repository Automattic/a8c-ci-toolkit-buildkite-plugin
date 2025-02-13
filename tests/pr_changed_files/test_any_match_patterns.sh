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
assert_result 0 $result "$output" "true" "Should match .swift files and output 'true'"

# [Test] Match multiple patterns
output=$(pr_changed_files --any-match 'docs/*.md' '*.rb')
result=$?
assert_result 0 $result "$output" "true" "Should match multiple patterns and output 'true'"

# [Test] Match files with spaces and special characters
output=$(pr_changed_files --any-match 'docs/read me.md' 'docs/special!@\*#$chars.md')
result=$?
assert_result 0 $result "$output" "true" "Should match files with spaces and special characters and output 'true'"

# [Test] Match files with spaces and special characters, even when using globbing
output=$(pr_changed_files --any-match 'docs/read me.md' 'docs/special*chars.md')
result=$?
assert_result 0 $result "$output" "true" "Should match files with spaces and special characters with globbing and output 'true'"

# [Test] No matches - check output string
output=$(pr_changed_files --any-match '*.js')
result=$?
assert_result 1 $result "$output" "false" "Should not match non-existent patterns and output 'false'"

# [Test] Directory pattern
output=$(pr_changed_files --any-match 'docs/*')
result=$?
assert_result 0 $result "$output" "true" "Should match directory patterns and output 'true'"

# [Test] Exact pattern matching
echo "swiftfile" > swiftfile.txt
git add swiftfile.txt
git commit -m "Add file with swift in name"

output=$(pr_changed_files --any-match '*.swift')
result=$?
assert_result 0 $result "$output" "true" "Should only match exact patterns and output 'true'"

echo "✅ Any-match pattern tests passed"
