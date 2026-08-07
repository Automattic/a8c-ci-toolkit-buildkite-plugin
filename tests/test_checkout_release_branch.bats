#!/usr/bin/env bats

# The command's own logic is the version resolution and the exact sequence of git commands
# it issues, so the tests stub `git` on PATH and assert on the recorded command log. What
# `reset --hard FETCH_HEAD` then does to a working copy is git's behaviour, not ours — and
# the plugin-tester image has no `git` to exercise it with anyway. Pinning the sequence is
# what guards the fix this command was extracted from: a `git pull` here would merge a
# diverged branch instead of discarding it.

SCRIPT="$BATS_TEST_DIRNAME/../bin/checkout_release_branch"

setup() {
	# The command reads both of these as fallbacks, so no test may inherit them.
	unset RELEASE_VERSION BUILDKITE_BRANCH

	TEST_DIR="$(mktemp -d)"
	GIT_LOG="$TEST_DIR/git-commands.log"
	export GIT_LOG

	# Record every invocation, one per line. Setting `GIT_FAIL_ON` to the start of a
	# subcommand makes that one fail, to check the script propagates git's exit code.
	mkdir -p "$TEST_DIR/bin"
	cat > "$TEST_DIR/bin/git" <<-'STUB'
		#!/usr/bin/env bash
		echo "$*" >> "$GIT_LOG"
		if [[ -n "${GIT_FAIL_ON:-}" && "$*" == ${GIT_FAIL_ON}* ]]; then
			echo "fatal: stubbed git failure" >&2
			exit 128
		fi
	STUB
	chmod +x "$TEST_DIR/bin/git"
	PATH="$TEST_DIR/bin:$PATH"
	export PATH
}

teardown() {
	rm -rf "$TEST_DIR"
}

# Assert the command checked out the release branch for `$1` and reset it onto `origin`.
assert_checked_out() {
	local version="$1"
	[ "$(sed -n '1p' "$GIT_LOG")" = "fetch origin release/$version" ]
	[ "$(sed -n '2p' "$GIT_LOG")" = "checkout release/$version" ]
	[ "$(sed -n '3p' "$GIT_LOG")" = "reset --hard FETCH_HEAD" ]
	[ "$(wc -l < "$GIT_LOG" | tr -d '[:space:]')" = "3" ]
}

assert_working_copy_untouched() {
	[ ! -s "$GIT_LOG" ]
}

@test "--help prints usage and exits 0" {
	run "$SCRIPT" --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "usage: checkout_release_branch" ]]
	assert_working_copy_untouched
}

@test "-h prints usage and exits 0" {
	run "$SCRIPT" -h
	[ "$status" -eq 0 ]
	[[ "$output" =~ "usage: checkout_release_branch" ]]
}

@test "an unknown option fails" {
	run "$SCRIPT" --nope
	[ "$status" -eq 1 ]
	[[ "$output" =~ "unknown option" ]]
	assert_working_copy_untouched
}

@test "more than one argument fails" {
	run "$SCRIPT" 1.2 3.4
	[ "$status" -eq 1 ]
	[[ "$output" =~ "too many arguments" ]]
	assert_working_copy_untouched
}

@test "the release version can come from the first argument" {
	run "$SCRIPT" 1.2
	[ "$status" -eq 0 ]
	assert_checked_out 1.2
}

@test "the release version can come from RELEASE_VERSION" {
	run env RELEASE_VERSION=1.2 "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_checked_out 1.2
}

@test "the release version can come from a release/* BUILDKITE_BRANCH" {
	run env BUILDKITE_BRANCH=release/1.2 "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_checked_out 1.2
}

@test "the argument takes precedence over RELEASE_VERSION" {
	run env RELEASE_VERSION=9.9 "$SCRIPT" 1.2
	[ "$status" -eq 0 ]
	assert_checked_out 1.2
}

@test "RELEASE_VERSION takes precedence over BUILDKITE_BRANCH" {
	run env RELEASE_VERSION=1.2 BUILDKITE_BRANCH=release/9.9 "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_checked_out 1.2
}

@test "an empty first argument falls through to RELEASE_VERSION" {
	run env RELEASE_VERSION=1.2 "$SCRIPT" ""
	[ "$status" -eq 0 ]
	assert_checked_out 1.2
}

@test "an empty RELEASE_VERSION falls through to BUILDKITE_BRANCH" {
	run env RELEASE_VERSION= BUILDKITE_BRANCH=release/1.2 "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_checked_out 1.2
}

@test "a version with slashes in it is kept whole" {
	run env BUILDKITE_BRANCH=release/25.4/hotfix "$SCRIPT"
	[ "$status" -eq 0 ]
	assert_checked_out 25.4/hotfix
}

@test "no version anywhere fails without touching the working copy" {
	run "$SCRIPT"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "no release version" ]]
	assert_working_copy_untouched
}

@test "a BUILDKITE_BRANCH that is not a release branch is not used as a version" {
	run env BUILDKITE_BRANCH=trunk "$SCRIPT"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "no release version" ]]
	assert_working_copy_untouched
}

@test "a BUILDKITE_BRANCH of exactly release/ yields no version" {
	run env BUILDKITE_BRANCH=release/ "$SCRIPT"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "no release version" ]]
	assert_working_copy_untouched
}

@test "a branch merely containing release/ is not used as a version" {
	run env BUILDKITE_BRANCH=feature/release/1.2 "$SCRIPT"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "no release version" ]]
}

@test "a failing fetch stops the command and propagates git's exit code" {
	run env GIT_FAIL_ON=fetch "$SCRIPT" 1.2
	[ "$status" -eq 128 ]
	# Only the fetch ran: no checkout or reset followed it.
	[ "$(wc -l < "$GIT_LOG" | tr -d '[:space:]')" = "1" ]
}

@test "a failing checkout stops the command before the reset" {
	run env GIT_FAIL_ON=checkout "$SCRIPT" 1.2
	[ "$status" -eq 128 ]
	[ "$(wc -l < "$GIT_LOG" | tr -d '[:space:]')" = "2" ]
}

# `reset --hard FETCH_HEAD` is the line this command was extracted to preserve, so its
# failure needs to surface rather than be swallowed by the last-command exit status.
@test "a failing reset propagates git's exit code" {
	run env GIT_FAIL_ON=reset "$SCRIPT" 1.2
	[ "$status" -eq 128 ]
	[ "$(wc -l < "$GIT_LOG" | tr -d '[:space:]')" = "3" ]
}
