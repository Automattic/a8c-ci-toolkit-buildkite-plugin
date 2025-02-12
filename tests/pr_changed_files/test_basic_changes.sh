#!/bin/bash -u

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo "--- :git: Testing basic changes detection"

# Create test repository
repo_path=$(create_tmp_repo_dir)
trap 'cleanup_git_repo "$repo_path"' EXIT

# Set up environment variables
export BUILDKITE_PULL_REQUEST="123"
export BUILDKITE_PULL_REQUEST_BASE_BRANCH="base"

# Initialize the repository
init_test_repo "$repo_path"

# [Test] No changes
pr_changed_files
result=$?
assert_return_code 1 $result "Should return 1 when no files changed"

# [Test] Single file change
echo "change" > new.txt
git add new.txt
git commit -m "Add new file"

pr_changed_files
result=$?
assert_return_code 0 $result "Should return 0 when files changed"

echo "✅ Basic changes tests passed"
