#!/bin/bash -u

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

# [Test] All changes in docs - exit code only
output=$(pr_changed_files --all-match 'docs/*')
result=$?
assert_result $result 0 "$output" "" "Should match when all changes are in docs"

# Test with stdout
output=$(pr_changed_files --stdout --all-match 'docs/*')
result=$?
assert_result $result 0 "$output" "true" "Should match when all changes are in docs with --stdout"

# [Test] All changes in docs with explicit patterns including spaces and special chars - exit code only
output=$(pr_changed_files --all-match 'docs/read me.md' 'docs/guide with spaces.md' 'docs/special\\!@\*#$chars.md')
result=$?
assert_result $result 0 "$output" "" "Should match when all changes match patterns with spaces and special chars"

# Test with stdout
output=$(pr_changed_files --stdout --all-match 'docs/read me.md' 'docs/guide with spaces.md' 'docs/special\\!@\*#$chars.md')
result=$?
assert_result $result 0 "$output" "true" "Should match when all changes match patterns with spaces and special chars with --stdout"

# [Test] All changes in docs with globbing patterns including spaces and special chars - exit code only
output=$(pr_changed_files --all-match 'docs/read me.md' 'docs/guide with spaces.md' 'docs/special\\!*.md')
result=$?
assert_result $result 0 "$output" "" "Should match when all changes match patterns with globbing"

# Test with stdout
output=$(pr_changed_files --stdout --all-match 'docs/read me.md' 'docs/guide with spaces.md' 'docs/special\\!*.md')
result=$?
assert_result $result 0 "$output" "true" "Should match when all changes match patterns with globbing with --stdout"

# [Test] Changes outside pattern - exit code only
echo "swift" > 'src/swift/main with spaces.swift'
echo "swift" > 'src/swift/special!\@#*$chars.swift'
git add .
git commit -m "Add swift file"

output=$(pr_changed_files --all-match 'docs/*')
result=$?
assert_result $result 1 "$output" "" "Should not match when changes exist outside patterns"

# Test with stdout
output=$(pr_changed_files --stdout --all-match 'docs/*')
result=$?
assert_result $result 0 "$output" "false" "Should not match when changes exist outside patterns with --stdout"

# [Test] Multiple patterns, all matching - exit code only
output=$(pr_changed_files --all-match 'docs/*' 'src/swift/main with spaces.swift' 'src/swift/special\!\\@#\*$chars.swift')
result=$?
assert_result $result 0 "$output" "" "Should match when all changes match multiple patterns"

# Test with stdout
output=$(pr_changed_files --stdout --all-match 'docs/*' 'src/swift/main with spaces.swift' 'src/swift/special\!\\@#\*$chars.swift')
result=$?
assert_result $result 0 "$output" "true" "Should match when all changes match multiple patterns with --stdout"

# [Test] Multiple patterns, all matching, including some using globbing - exit code only
output=$(pr_changed_files --all-match 'docs/*' 'src/swift/main with spaces.swift' 'src/swift/special*chars.swift')
result=$?
assert_result $result 0 "$output" "" "Should match when all changes match patterns with globbing"

# Test with stdout
output=$(pr_changed_files --stdout --all-match 'docs/*' 'src/swift/main with spaces.swift' 'src/swift/special*chars.swift')
result=$?
assert_result $result 0 "$output" "true" "Should match when all changes match patterns with globbing with --stdout"

echo "✅ All-match pattern tests passed"
