#!/bin/bash -u

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "--- :git: Testing edge cases"

# Create test repository
repo_path=$(create_tmp_repo_dir)
trap 'cleanup_git_repo "$repo_path"' EXIT

# Set up environment variables
export BUILDKITE_PULL_REQUEST="123"
export BUILDKITE_PULL_REQUEST_BASE_BRANCH="base"

# Initialize the repository
init_test_repo "$repo_path"

# [Test] Invalid PR environment
unset BUILDKITE_PULL_REQUEST
output=$(pr_changed_files 2>&1)
result=$?
assert_result $result 255 "$output" "Error: this tool can only be called from a Buildkite PR job" "Should fail when not in PR environment"

export BUILDKITE_PULL_REQUEST="123"

# [Test] No patterns provided
output=$(pr_changed_files --any-match 2>&1)
result=$?
assert_result $result 255 "$output" "Error: must specify at least one file pattern" "Should fail when no patterns provided"

# [Test] Flag followed by another flag
output=$(pr_changed_files --any-match --something 2>&1)
result=$?
assert_result $result 255 "$output" "Error: must specify at least one file pattern" "Should fail with correct error when flag is followed by another flag"

# [Test] Mutually exclusive options
output=$(pr_changed_files --any-match "*.txt" --all-match "*.md" 2>&1)
result=$?
assert_result $result 255 "$output" "Error: either specify --all-match or --any-match; cannot specify both" "Should fail with correct error when using mutually exclusive options"

# [Test] Files with spaces and special characters
mkdir -p 'folder with spaces/nested!\@*#$folder'
echo "test" > 'folder with spaces/file with spaces.txt'
echo "test" > 'folder with spaces/nested!\@*#$folder/file_with_!@*#$chars.txt'
git add .
git commit -m "Add files with special characters"

# Test with exit code only
output=$(pr_changed_files)
result=$?
assert_result $result 0 "$output" "" "Should handle files with spaces and special characters"

# Test with stdout
output=$(pr_changed_files --stdout)
result=$?
assert_result $result 0 "$output" "true" "Should handle files with spaces and special characters with --stdout"

# [Test] Pattern matching with spaces and special characters - exit code only
output=$(pr_changed_files --any-match '*spaces.txt')
result=$?
assert_result $result 0 "$output" "" "Should match files with special characters in path"

# Test with stdout
output=$(pr_changed_files --stdout --any-match '*spaces.txt')
result=$?
assert_result $result 0 "$output" "true" "Should match files with special characters in path with --stdout"

# [Test] No changes between branches - exit code only
git checkout -b no_changes base
output=$(pr_changed_files)
result=$?
assert_result $result 1 "$output" "" "Should handle no changes between branches"

# Test with stdout
output=$(pr_changed_files --stdout)
result=$?
assert_result $result 0 "$output" "false" "Should handle no changes between branches with --stdout"

# [Test] Empty commit - exit code only
git checkout -b empty_commit base
git commit --allow-empty -m "Empty commit"
output=$(pr_changed_files)
result=$?
assert_result $result 1 "$output" "" "Should handle empty commit"

# Test with stdout
output=$(pr_changed_files --stdout)
result=$?
assert_result $result 0 "$output" "false" "Should handle empty commit with --stdout"

# [Test] Empty repository state - exit code only
git checkout --orphan empty
git rm -rf .
git commit --allow-empty -m "Empty initial commit"

output=$(pr_changed_files)
result=$?
assert_result $result 1 "$output" "" "Should handle empty repository state"

# Test with stdout
output=$(pr_changed_files --stdout)
result=$?
assert_result $result 0 "$output" "false" "Should handle empty repository state with --stdout"

echo -e "\n✅ Edge cases tests passed"
