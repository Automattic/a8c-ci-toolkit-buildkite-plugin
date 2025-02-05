#!/bin/bash -eu

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
if pr_changed_files 2>/dev/null; then
    echo "Should fail when not in PR environment"
    exit 1
fi

export BUILDKITE_PULL_REQUEST="123"

# [Test] No patterns provided
if pr_changed_files --includes 2>/dev/null; then
    echo "Should fail when no patterns provided"
    exit 1
fi

# [Test] Mutually exclusive options
if pr_changed_files --includes "*.txt" --only-in "*.md" 2>/dev/null; then
    echo "Should fail when using both --includes and --only-in"
    exit 1
fi

# [Test] Files with spaces and special characters
mkdir -p "folder with spaces/nested\!\@\#\$folder"
echo "test" > "folder with spaces/file with spaces.txt"
echo "test" > "folder with spaces/nested\!\@\#\$folder/file_with_\!\@\#.txt"
git add .
git commit -m "Add files with special characters"

result=$(pr_changed_files)
assert_output "true" "$result" "Should handle files with spaces and special characters"

# [Test] Pattern matching with spaces and special characters
result=$(pr_changed_files --includes "*spaces.txt")
assert_output "true" "$result" "Should match files with special characters in path"

result=$(pr_changed_files --only-in "folder with spaces/*")
assert_output "true" "$result" "Should handle directory patterns with spaces"

# [Test] Empty repository state
git checkout --orphan empty
git rm -rf .

result=$(pr_changed_files)
assert_output "false" "$result" "Should handle empty repository state"

echo "✅ Edge cases tests passed"
