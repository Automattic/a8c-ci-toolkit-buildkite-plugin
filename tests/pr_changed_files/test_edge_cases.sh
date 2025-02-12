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
pr_changed_files
result=$?
assert_return_code 255 $result "Should fail when not in PR environment"

export BUILDKITE_PULL_REQUEST="123"

# [Test] No patterns provided
pr_changed_files --any-match
result=$?
assert_return_code 255 $result "Should fail when no patterns provided"

# [Test] Flag followed by another flag
output=$(pr_changed_files --any-match --something 2>&1)
result=$?
assert_output "Error: must specify at least one file pattern" "$output" "Should fail with correct error when flag is followed by another flag"
assert_return_code 255 $result "Should fail with correct error when flag is followed by another flag"

# [Test] Mutually exclusive options
output=$(pr_changed_files --any-match "*.txt" --all-match "*.md" 2>&1)
result=$?
assert_return_code 255 $result "Should fail with correct error when using mutually exclusive options"
assert_output "Error: either specify --all-match or --any-match; cannot specify both" "$output" "Should fail with correct error when using mutually exclusive options"

# [Test] Files with spaces and special characters
mkdir -p 'folder with spaces/nested!\@*#$folder'
echo "test" > 'folder with spaces/file with spaces.txt'
echo "test" > 'folder with spaces/nested!\@*#$folder/file_with_!@*#$chars.txt'
git add .
git commit -m "Add files with special characters"

pr_changed_files
result=$?
assert_return_code 0 $result "Should handle files with spaces and special characters"

# [Test] Pattern matching with spaces and special characters
pr_changed_files --any-match '*spaces.txt'
result=$?
assert_return_code 0 $result "Should match files with special characters in path"

pr_changed_files --all-match 'folder with spaces/*'
result=$?
assert_return_code 0 $result "Should handle directory patterns with spaces"

# [Test] No changes between branches
git checkout -b no_changes base
pr_changed_files
result=$?
assert_return_code 1 $result "Should handle no changes between branches"

# [Test] Empty commit
git checkout -b empty_commit base
git commit --allow-empty -m "Empty commit"
pr_changed_files
result=$?
assert_return_code 1 $result "Should handle empty commit"

# [Test] Empty repository state
git checkout --orphan empty
git rm -rf .
git commit --allow-empty -m "Empty initial commit"

pr_changed_files
result=$?
assert_return_code 1 $result "Should handle empty repository state"

echo -e "\n✅ Edge cases tests passed"
