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

# [Test] Match specific extension - exit code only
output=$(pr_changed_files --any-match '*.swift')
result=$?
assert_result $result 0 "$output" "" "Should match .swift files"

# Test with stdout
output=$(pr_changed_files --stdout --any-match '*.swift')
result=$?
assert_result $result 0 "$output" "true" "Should match .swift files with --stdout"

# [Test] Match multiple patterns - exit code only
output=$(pr_changed_files --any-match 'docs/*.md' '*.rb')
result=$?
assert_result $result 0 "$output" "" "Should match multiple patterns"

# Test with stdout
output=$(pr_changed_files --stdout --any-match 'docs/*.md' '*.rb')
result=$?
assert_result $result 0 "$output" "true" "Should match multiple patterns with --stdout"

# [Test] Match files with spaces and special characters - exit code only
output=$(pr_changed_files --any-match 'docs/read me.md' 'docs/special!@*#$chars.md')
result=$?
assert_result $result 0 "$output" "" "Should match files with spaces and special characters"

# Test with stdout
output=$(pr_changed_files --stdout --any-match 'docs/read me.md' 'docs/special!@*#$chars.md')
result=$?
assert_result $result 0 "$output" "true" "Should match files with spaces and special characters with --stdout"

# [Test] No matches - exit code only
output=$(pr_changed_files --any-match '*.js')
result=$?
assert_result $result 1 "$output" "" "Should not match non-existent patterns"

# Test with stdout
output=$(pr_changed_files --stdout --any-match '*.js')
result=$?
assert_result $result 0 "$output" "false" "Should not match non-existent patterns with --stdout"

# [Test] Directory pattern - exit code only
output=$(pr_changed_files --any-match 'docs/*')
result=$?
assert_result $result 0 "$output" "" "Should match directory patterns"

# Test with stdout
output=$(pr_changed_files --stdout --any-match 'docs/*')
result=$?
assert_result $result 0 "$output" "true" "Should match directory patterns with --stdout"

# [Test] Exact pattern matching - exit code only
echo "swiftfile" > swiftfile.txt
git add swiftfile.txt
git commit -m "Add file with swift in name"

output=$(pr_changed_files --any-match '*.swift')
result=$?
assert_result $result 0 "$output" "" "Should only match exact patterns"

# Test with stdout
output=$(pr_changed_files --stdout --any-match '*.swift')
result=$?
assert_result $result 0 "$output" "true" "Should only match exact patterns with --stdout"

echo "✅ Any-match pattern tests passed"
