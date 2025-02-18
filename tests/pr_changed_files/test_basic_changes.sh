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

# [Test] No changes - exit code only
output=$(pr_changed_files)
result=$?
assert_result 1 $result "" "$output" "Should return 1 when no files changed"

# [Test] No changes - with stdout
output=$(pr_changed_files --stdout)
result=$?
assert_result 0 $result "false" "$output" "Should output 'false' and return 0 with --stdout when no files changed"

# [Test] Single file change - exit code only
echo "change" > new.txt
git add new.txt
git commit -m "Add new file"

output=$(pr_changed_files)
result=$?
assert_result 0 $result "$output" "" "Should return 0 when files changed"

# [Test] Single file change - with stdout
output=$(pr_changed_files --stdout)
result=$?
assert_result 0 $result "$output" "true" "Should output 'true' and return 0 with --stdout when files changed"

echo "✅ Basic changes tests passed"
