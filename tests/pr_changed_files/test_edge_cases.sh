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
assert_result 255 $result "$output" "Error: this tool can only be called from a Buildkite PR job" "Should fail when not in PR environment"

export BUILDKITE_PULL_REQUEST="123"

# [Test] No patterns provided
output=$(pr_changed_files --any-match 2>&1)
result=$?
assert_result 255 $result "$output" "Error: must specify at least one file pattern" "Should fail when no patterns provided"

# [Test] Flag followed by another flag
output=$(pr_changed_files --any-match --something 2>&1)
result=$?
assert_result 255 $result "$output" "Error: must specify at least one file pattern" "Should fail with correct error when flag is followed by another flag"

# [Test] Mutually exclusive options
output=$(pr_changed_files --any-match "*.txt" --all-match "*.md" 2>&1)
result=$?
assert_result 255 $result "$output" "Error: either specify --all-match or --any-match; cannot specify both" "Should fail with correct error when using mutually exclusive options"

# [Test] Files with spaces and special characters
mkdir -p 'folder with spaces/nested!\@*#$folder'
echo "test" > 'folder with spaces/file with spaces.txt'
echo "test" > 'folder with spaces/nested!\@*#$folder/file_with_!@*#$chars.txt'
git add .
git commit -m "Add files with special characters"

output=$(pr_changed_files)
result=$?
assert_result 0 $result "$output" "true" "Should handle files with spaces and special characters"

# [Test] Pattern matching with spaces and special characters
output=$(pr_changed_files --any-match '*spaces.txt')
result=$?
assert_result 0 $result "$output" "true" "Should match files with special characters in path"

output=$(pr_changed_files --all-match 'folder with spaces/*')
result=$?
assert_result 0 $result "$output" "true" "Should handle directory patterns with spaces"

# [Test] No changes between branches
git checkout -b no_changes base
output=$(pr_changed_files)
result=$?
assert_result 1 $result "$output" "false" "Should handle no changes between branches"

# [Test] Empty commit
git checkout -b empty_commit base
git commit --allow-empty -m "Empty commit"
output=$(pr_changed_files)
result=$?
assert_result 1 $result "$output" "false" "Should handle empty commit"

# [Test] Empty repository state
git checkout --orphan empty
git rm -rf .
git commit --allow-empty -m "Empty initial commit"

output=$(pr_changed_files)
result=$?
assert_result 1 $result "$output" "false" "Should handle empty repository state"

echo -e "\n✅ Edge cases tests passed"
