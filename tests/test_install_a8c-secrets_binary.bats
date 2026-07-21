#!/usr/bin/env bats

# The platform-mapping and checksum-pinning contract is unit-tested by sourcing the
# script (guarded so `main` doesn't run) and calling its pure functions directly. The
# unsupported-platform paths are checked by running the command with `--os`/`--arch` set
# to a bad target, which errors before any download. The real download/verify/install
# path needs a release binary and is exercised on real CI via a consuming repo.

SCRIPT="$BATS_TEST_DIRNAME/../bin/install_a8c-secrets_binary"

# Source the script in a subshell and call one of its functions, so `set -e` and the
# EXIT trap stay contained to that subshell.
call() {
	run bash -c "source '$SCRIPT'; $1"
}

@test "--help prints usage and exits 0" {
	run "$SCRIPT" --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "usage: install_a8c-secrets_binary" ]]
}

@test "unknown option fails" {
	run "$SCRIPT" --nope
	[ "$status" -eq 1 ]
	[[ "$output" =~ "unknown option" ]]
}

@test "macOS arm64 maps to the aarch64-apple-darwin triple" {
	call "resolve_target_triple Darwin arm64"
	[ "$status" -eq 0 ]
	[ "$output" = "aarch64-apple-darwin" ]
}

@test "Linux x86_64 maps to the linux-gnu triple" {
	call "resolve_target_triple Linux x86_64"
	[ "$status" -eq 0 ]
	[ "$output" = "x86_64-unknown-linux-gnu" ]
}

@test "Windows x86_64 maps to the windows-gnu triple" {
	call "resolve_target_triple MINGW64_NT-10.0 x86_64"
	[ "$status" -eq 0 ]
	[ "$output" = "x86_64-pc-windows-gnu" ]
}

@test "an unsupported architecture has no triple" {
	call "resolve_target_triple Linux riscv64"
	[ "$status" -ne 0 ]
	[ -z "$output" ]
}

@test "each supported triple has a pinned checksum" {
	call "expected_checksum aarch64-apple-darwin"
	[ "$output" = "2b59604261053d2b57a805c53e3b727c43b750e821b587c0492dee7f717bab24" ]
	call "expected_checksum x86_64-unknown-linux-gnu"
	[ "$output" = "b8fd670c430843ff5af954a85903dc1726d5ca8e3294f725e5e521ac86683bf7" ]
	call "expected_checksum x86_64-pc-windows-gnu"
	[ "$output" = "fd58cc1f7330de1078042ad1cb7afcb127ac66e8de840f202b03b70fd829b086" ]
}

@test "unsupported platform exits 2 before downloading" {
	run "$SCRIPT" --os Plan9 --arch x86_64
	[ "$status" -eq 2 ]
	[[ "$output" =~ "Unsupported platform" ]]
}

@test "a resolvable target without a pinned checksum is refused" {
	# macOS Intel resolves to a valid triple, but a8c-secrets 1.0.0 publishes no
	# x86_64-apple-darwin asset, so no checksum is pinned for it.
	run "$SCRIPT" --os Darwin --arch x86_64
	[ "$status" -eq 2 ]
	[[ "$output" =~ "No pinned checksum" ]]
}

@test "an option missing its value fails" {
	run "$SCRIPT" --os
	[ "$status" -eq 1 ]
	[[ "$output" =~ "missing value for --os" ]]
}

@test "--arch alone still detects the host OS" {
	# A bogus arch on the host's own OS resolves to no triple, proving --arch was read
	# and the OS fell back to `uname -s`.
	run "$SCRIPT" --arch riscv64
	[ "$status" -eq 2 ]
	[[ "$output" =~ "os=$(uname -s) arch=riscv64" ]]
}
