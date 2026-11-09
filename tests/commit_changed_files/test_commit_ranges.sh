#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../pr_changed_files/test_helpers.sh"

echo "--- :git: Testing commit ranges"

repo_path=$(create_tmp_repo_dir)
trap 'cd "$REPO_ROOT"; cleanup_git_repo "$repo_path"' EXIT
init_test_repo "$repo_path"
unset BUILDKITE_PULL_REQUEST BUILDKITE_PULL_REQUEST_BASE_BRANCH
range_base=$(git rev-parse HEAD)
root_commit=$(git rev-list --max-parents=0 HEAD)

mkdir -p src docs
echo source > 'src/app.swift'
git add .
git commit -m 'Add source'
source_commit=$(git rev-parse HEAD)

assert_command_result 0 '' 'Default detects a change without PR context' commit_changed_files
assert_command_result 0 true 'Changed files with stdout' commit_changed_files --stdout
assert_command_result 0 '' 'All changed files match' commit_changed_files --all-match 'src/*'
assert_command_result 1 '' 'No matching files' commit_changed_files --any-match 'docs/*'
assert_command_result 0 false 'No match with stdout' commit_changed_files --stdout --any-match 'docs/*'

echo docs > 'docs/read me.md'
# Git quotes tabs in non-NUL output, so this catches a regression to line-based parsing.
echo docs > $'docs/tab\tname.md'
git add .
git commit -m 'Add documentation'

assert_command_result 0 '' 'Default only checks the latest commit' commit_changed_files --all-match 'docs/*'
assert_command_result 0 '' 'Quoted filename stays intact' commit_changed_files --any-match $'docs/tab\tname.md'
assert_command_result 1 '' 'Default excludes earlier changes' commit_changed_files --any-match 'src/*'
assert_command_result 0 true 'Select an earlier commit' commit_changed_files --commit "$source_commit" --stdout --all-match 'src/*'
assert_command_result 0 '' 'Explicit base includes earlier changes' commit_changed_files --base "$range_base" --any-match 'src/*'
assert_command_result 0 '' 'Explicit range includes source and docs' commit_changed_files --base "$range_base" --all-match 'src/*' 'docs/*'
assert_command_result 1 '' 'Explicit range is not docs-only' commit_changed_files --base "$range_base" --all-match 'docs/*'

# Empty diffs are false in every mode, even with --all-match.
assert_command_result 1 '' 'Empty diff without matching' commit_changed_files --base HEAD
assert_command_result 0 false 'Empty diff without matching, with stdout' commit_changed_files --base HEAD --stdout
for mode in --all-match --any-match; do
    assert_command_result 1 '' "Empty diff ($mode)" commit_changed_files --base HEAD "$mode" '*'
    assert_command_result 0 false "Empty diff with stdout ($mode)" commit_changed_files --base HEAD --stdout "$mode" '*'
done

# Merge a branch into a target that has also advanced. Only the merged changes
# belong to the merge commit; the target's own change is in its first parent.
git checkout -b target "$range_base"
echo target > target.txt
git add .
git commit -m 'Advance target branch'
target_commit=$(git rev-parse HEAD)
git merge --no-ff pr -m 'Merge source and docs'

assert_command_result 0 '' 'Merge includes source' commit_changed_files --any-match 'src/*'
assert_command_result 0 '' 'Merge includes docs' commit_changed_files --any-match 'docs/*'
assert_command_result 1 '' 'Merge excludes target changes' commit_changed_files --any-match 'target.txt'
assert_command_result 0 true 'Merge compares against first parent' commit_changed_files --stdout --all-match 'src/*' 'docs/*'

# A non-ancestor --base compares snapshots, not the common ancestor.
assert_command_result 0 '' 'Divergent base includes files from the base side' commit_changed_files --base pr --commit "$target_commit" --any-match 'src/*'
assert_command_result 0 '' 'Divergent base includes files from the commit side' commit_changed_files --base pr --commit "$target_commit" --any-match 'target.txt'

git config diff.renames true
git mv 'src/app.swift' 'docs/app.md'
git commit -m 'Rename source into docs'
assert_command_result 0 '' 'Rename includes old path' commit_changed_files --any-match 'src/*'
assert_command_result 0 true 'Rename includes new path' commit_changed_files --stdout --any-match 'docs/*'
assert_command_result 1 '' 'Rename out of source is not docs-only' commit_changed_files --all-match 'docs/*'

for option in --commit --base; do
    assert_command_result 255 '' "Missing $option value" commit_changed_files "$option"
    assert_command_result 255 '' "Flag is not a $option value" commit_changed_files "$option" --stdout
    for value in '' nonexistent-ref; do
        assert_command_result 255 '' "Invalid $option value: '$value'" commit_changed_files "$option" "$value"
        assert_command_result 255 '' "Invalid $option value with stdout: '$value'" commit_changed_files --stdout "$option" "$value"
    done
done

assert_command_result 255 '' 'Root commit has no default parent' commit_changed_files --commit "$root_commit"
assert_command_result 255 '' 'Root commit with stdout has no boolean' commit_changed_files --stdout --commit "$root_commit" 2> "$repo_path/error"
assert_equal "$(cat "$repo_path/error")" "Error: commit '$root_commit' has no parent available (root commit or shallow clone); fetch more history or supply an explicit --base." 'Root commit error is actionable without Git noise'

# file:// is required: a plain local clone ignores --depth.
git clone --depth 1 --branch target "file://$repo_path/local" "$repo_path/shallow"
cd "$repo_path/shallow"
assert_command_result 255 '' 'Shallow commit has no default parent' commit_changed_files --stdout 2> "$repo_path/error"
assert_equal "$(cat "$repo_path/error")" "Error: commit 'HEAD' has no parent available (root commit or shallow clone); fetch more history or supply an explicit --base." 'Shallow clone error explains missing history'

echo '✅ Commit range tests passed'
