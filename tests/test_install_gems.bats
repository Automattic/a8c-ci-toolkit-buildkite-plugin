#!/usr/bin/env bats

# `install_gems` is tested with stubs for the system and Ruby tools it calls, and for the
# helpers that talk to the cache bucket. Each stub logs its arguments, so the tests can
# check the cache key that `install_gems` computes.

BIN="$BATS_TEST_DIRNAME/../bin"

setup() {
	STUBS="$BATS_TEST_TMPDIR/stubs"
	CALLS="$BATS_TEST_TMPDIR/calls.log"
	mkdir -p "$STUBS"
	export CALLS

	cat > "$STUBS/uname" <<-'EOF'
		#!/usr/bin/env bash
		case "$1" in
		  -s) echo "${FAKE_PLATFORM:-Darwin}" ;;
		  -m) echo "arm64" ;;
		esac
	EOF
	cat > "$STUBS/brew" <<-'EOF'
		#!/usr/bin/env bash
		printf '%b' "${FAKE_BREW_FORMULAE:-}"
	EOF
	cat > "$STUBS/rbenv" <<-'EOF'
		#!/usr/bin/env bash
		case "$1" in
		  version-name)
		    if [[ -n "${FAKE_MISSING_RUBY:-}" ]]; then
		      echo "rbenv: version \`$FAKE_MISSING_RUBY' is not installed (set by .ruby-version)" >&2
		      exit 1
		    fi
		    echo "3.4.9"
		    ;;
		  versions) printf '3.3.11\n3.4.9\n4.0.5\n' ;;
		esac
	EOF
	cat > "$STUBS/hash_file" <<-'EOF'
		#!/usr/bin/env bash
		echo "abc123"
	EOF
	for stub in restore_cache save_cache gem bundle; do
		printf '#!/usr/bin/env bash\necho "%s $*" >> "$CALLS"\n' "$stub" > "$STUBS/$stub"
	done
	chmod +x "$STUBS"/*

	export PATH="$STUBS:$BIN:$PATH"
	export BUILDKITE_PIPELINE_SLUG="my-pipeline"

	cd "$BATS_TEST_TMPDIR"
}

write_gemfile_lock() {
	printf 'GEM\n  specs:\n%b\nBUNDLED WITH\n   2.6.9\n' "$1" > Gemfile.lock
}

@test "the key has no OpenSSL part when the Gemfile.lock doesn't include the openssl gem" {
	write_gemfile_lock '    fastlane (2.241.2)\n      openssl-signature_algorithm (~> 1.0)\n'
	export FAKE_BREW_FORMULAE='openssl@4 4.1.0\n'

	run "$BIN/install_gems"
	[ "$status" -eq 0 ]
	grep -qx "restore_cache my-pipeline-Darwin-arm64-ruby3.4.9-abc123" "$CALLS"
	grep -qx "save_cache vendor/bundle my-pipeline-Darwin-arm64-ruby3.4.9-abc123" "$CALLS"
}

@test "the key includes the Homebrew OpenSSL formulae when the Gemfile.lock includes the openssl gem" {
	write_gemfile_lock '    openssl (4.0.2)\n'
	export FAKE_BREW_FORMULAE='awscli 2.31.0\nopenssl@3 3.6.5\nopenssl@4 4.1.0\n'

	run "$BIN/install_gems"
	[ "$status" -eq 0 ]
	grep -qx "restore_cache my-pipeline-Darwin-arm64-openssl@3-3.6.5-openssl@4-4.1.0-ruby3.4.9-abc123" "$CALLS"
	grep -qx "save_cache vendor/bundle my-pipeline-Darwin-arm64-openssl@3-3.6.5-openssl@4-4.1.0-ruby3.4.9-abc123" "$CALLS"
}

@test "images with different Homebrew OpenSSL formulae get different keys" {
	write_gemfile_lock '    openssl (4.0.2)\n'

	FAKE_BREW_FORMULAE='openssl@3 3.6.5\n' run "$BIN/install_gems"
	[ "$status" -eq 0 ]
	FAKE_BREW_FORMULAE='openssl@4 4.1.0\n' run "$BIN/install_gems"
	[ "$status" -eq 0 ]

	grep -qx "restore_cache my-pipeline-Darwin-arm64-openssl@3-3.6.5-ruby3.4.9-abc123" "$CALLS"
	grep -qx "restore_cache my-pipeline-Darwin-arm64-openssl@4-4.1.0-ruby3.4.9-abc123" "$CALLS"
}

@test "the key says when no Homebrew OpenSSL is installed" {
	write_gemfile_lock '    openssl (4.0.2)\n'
	export FAKE_BREW_FORMULAE='awscli 2.31.0\n'

	run "$BIN/install_gems"
	[ "$status" -eq 0 ]
	grep -qx "restore_cache my-pipeline-Darwin-arm64-openssl-none-ruby3.4.9-abc123" "$CALLS"
}

@test "the key has no OpenSSL part on Linux" {
	write_gemfile_lock '    openssl (4.0.2)\n'
	export FAKE_PLATFORM='Linux'
	export FAKE_BREW_FORMULAE='openssl@4 4.1.0\n'

	run "$BIN/install_gems"
	[ "$status" -eq 0 ]
	grep -qx "restore_cache my-pipeline-Linux-arm64-ruby3.4.9-abc123" "$CALLS"
}

@test "a Ruby version missing from rbenv fails before touching the cache and lists the installed ones" {
	write_gemfile_lock '    fastlane (2.241.2)\n'
	export FAKE_MISSING_RUBY='3.4.12'

	run "$BIN/install_gems"
	[ "$status" -eq 1 ]
	[[ "$output" == *"rbenv: version \`3.4.12' is not installed"* ]]
	[[ "$output" == *"Ruby versions installed on this agent:"$'\n'"  3.3.11"$'\n'"  3.4.9"$'\n'"  4.0.5"* ]]
	[ ! -e "$CALLS" ]
}
