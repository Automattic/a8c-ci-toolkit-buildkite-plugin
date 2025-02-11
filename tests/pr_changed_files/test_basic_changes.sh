#!/bin/bash -eu

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
result=$(pr_changed_files)
assert_output "false" "$result" "Should return false when no files changed"

# [Test] Single file change
echo "change" > new.txt
git add new.txt
git commit -m "Add new file"

result=$(pr_changed_files)
assert_output "true" "$result" "Should return true when files changed"

echo "✅ Basic changes tests passed"
