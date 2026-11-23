#!/usr/bin/env bats

# `annotate_test_failures` is tested with stubs for `rbenv` and `ruby`. The `ruby` stub records
# which Ruby version it would run and which script, so the tests can check the wrapper picks the
# calling repo's Ruby instead of the plugin's own `.ruby-version`.

BIN="$BATS_TEST_DIRNAME/../bin"

setup() {
	STUBS="$BATS_TEST_TMPDIR/stubs"
	CALLER="$BATS_TEST_TMPDIR/caller-repo"
	mkdir -p "$STUBS" "$CALLER"

	cat > "$STUBS/rbenv" <<-'EOF'
		#!/usr/bin/env bash
		[[ "$1" == version-name ]] && cat "$PWD/.ruby-version"
	EOF
	cat > "$STUBS/ruby" <<-'EOF'
		#!/usr/bin/env bash
		echo "RBENV_VERSION=${RBENV_VERSION:-unset}"
		echo "script=$(basename "$1")"
		shift
		echo "args=$*"
	EOF
	chmod +x "$STUBS/rbenv" "$STUBS/ruby"

	echo "9.9.9" > "$CALLER/.ruby-version"
	cd "$CALLER" || return 1
}

@test "Runs on the Ruby named by the calling repo's .ruby-version" {
	run env PATH="$STUBS:$PATH" "$BIN/annotate_test_failures" report.junit --slack builds

	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "RBENV_VERSION=9.9.9" ]
	[ "${lines[1]}" = "script=annotate_test_failures.rb" ]
	[ "${lines[2]}" = "args=report.junit --slack builds" ]
}

@test "Keeps a RBENV_VERSION the caller already set" {
	run env PATH="$STUBS:$PATH" RBENV_VERSION=1.2.3 "$BIN/annotate_test_failures"

	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "RBENV_VERSION=1.2.3" ]
}

@test "Leaves RBENV_VERSION unset when rbenv is not installed" {
	rm "$STUBS/rbenv"
	ruby_dir="$(dirname "$(command -v bash)")"
	run env -u RBENV_VERSION PATH="$STUBS:$ruby_dir:/usr/bin:/bin" "$BIN/annotate_test_failures"

	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "RBENV_VERSION=unset" ]
}
