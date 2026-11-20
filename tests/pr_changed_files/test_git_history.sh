#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helpers.sh"

echo '--- :git: Testing PR Git history'

repo_path=$(create_tmp_repo_dir)
trap 'cd "$REPO_ROOT"; cleanup_git_repo "$repo_path"' EXIT
export BUILDKITE_PULL_REQUEST=123
export BUILDKITE_PULL_REQUEST_BASE_BRANCH=base
init_test_repo "$repo_path"

for option in --base --commit; do
    assert_command_result 255 '' "PRs reject $option" pr_changed_files --stdout "$option" HEAD
done
unset BUILDKITE_PULL_REQUEST_BASE_BRANCH
assert_command_result 255 '' 'Missing PR base branch is an error' pr_changed_files --stdout 2> "$repo_path/error"
assert_equal "$(cat "$repo_path/error")" 'Error: missing BUILDKITE_PULL_REQUEST_BASE_BRANCH' 'Missing PR base branch fails before fetch'
export BUILDKITE_PULL_REQUEST_BASE_BRANCH=base

# Put the source file in the base so that the PR diff is a rename, not an add.
git checkout base
mkdir -p src
echo source > 'src/app.swift'
git add .
git commit -m 'Add source to base'
git push origin base
git checkout pr
git merge --ff-only base
mkdir -p docs
git mv 'src/app.swift' 'docs/app.md'
git commit -m 'Rename source into docs'
git config diff.renames true
git push origin pr

assert_command_result 0 '' 'PR rename includes old path' pr_changed_files --any-match 'src/*'
assert_command_result 0 true 'PR rename includes new path' pr_changed_files --stdout --any-match 'docs/*'
assert_command_result 1 '' 'PR rename is not docs-only' pr_changed_files --all-match 'docs/*'

# A single-branch clone has no origin/base tracking ref. A same-named tag on the
# remote must not be fetched instead of the branch into FETCH_HEAD.
git clone --single-branch --branch pr "$repo_path/remote" "$repo_path/single-branch"
cd "$repo_path/single-branch"
git tag base HEAD
git push origin refs/tags/base
assert_command_result 1 '' 'Fixture does not track origin/base' git show-ref --verify --quiet refs/remotes/origin/base
assert_command_result 0 true 'Untracked base uses the fetched branch' pr_changed_files --stdout --any-match 'src/*'
assert_command_result 0 '' 'Untracked base preserves matching' pr_changed_files --all-match 'src/*' 'docs/*'
git push origin :refs/tags/base

git clone --depth 1 --branch pr "file://$repo_path/remote" "$repo_path/shallow"
cd "$repo_path/shallow"
assert_command_result 255 '' 'Shallow PR with no merge base errors' pr_changed_files
assert_command_result 255 '' 'Shallow PR prints no boolean' pr_changed_files --stdout 2> "$repo_path/error"
assert_equal "$(cat "$repo_path/error")" 'Error: could not determine PR merge base' 'Shallow PR fails at merge-base detection, not fetch'

cd "$repo_path/local"
export BUILDKITE_PULL_REQUEST_BASE_BRANCH=missing-branch
assert_command_result 255 '' 'Failed fetch prints no boolean' pr_changed_files --stdout
export BUILDKITE_PULL_REQUEST_BASE_BRANCH=base

# Criss-cross merges have two best common ancestors. Build that graph directly
# to keep the fixture small and independent of merge strategy/configuration.
tree=$(git rev-parse 'HEAD^{tree}')
left=$(git commit-tree "$tree" -p base -m left)
right=$(git commit-tree "$tree" -p base -m right)
left_merge=$(git commit-tree "$tree" -p "$left" -p "$right" -m left-merge)
right_merge=$(git commit-tree "$tree" -p "$right" -p "$left" -m right-merge)
git push origin "$left_merge:refs/heads/base"
git checkout --detach "$right_merge"
assert_command_result 255 '' 'Multiple merge bases are an error' pr_changed_files
assert_command_result 255 '' 'Multiple merge bases print no boolean' pr_changed_files --stdout 2> "$repo_path/error"
assert_equal "$(cat "$repo_path/error")" 'Error: multiple PR merge bases found' 'Criss-cross fixture reaches the ambiguous-base guard'

echo '✅ PR Git history tests passed'
