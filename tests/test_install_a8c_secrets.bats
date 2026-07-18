#!/usr/bin/env bats

# These cases cover the platform-mapping and checksum-pinning contract via `--print-plan`,
# which resolves the target, asset, URL and expected checksum without touching the network.
# The download/verify/install path needs a real release binary and is exercised on real CI
# via a consuming repo.

SCRIPT="$BATS_TEST_DIRNAME/../bin/install_a8c_secrets"

plan_for() {
	A8C_SECRETS_OS="$1" A8C_SECRETS_ARCH="$2" run "$SCRIPT" --print-plan
}

@test "--help prints usage and exits 0" {
	run "$SCRIPT" --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "usage: install_a8c_secrets" ]]
}

@test "unknown option fails" {
	run "$SCRIPT" --nope
	[ "$status" -eq 1 ]
	[[ "$output" =~ "unknown option" ]]
}

@test "macOS arm64 resolves to the aarch64-apple-darwin asset and checksum" {
	plan_for Darwin arm64
	[ "$status" -eq 0 ]
	[[ "$output" =~ "target:   aarch64-apple-darwin" ]]
	[[ "$output" =~ "asset:    a8c-secrets-aarch64-apple-darwin-1.0.0" ]]
	[[ "$output" =~ "https://github.com/Automattic/a8c-secrets/releases/download/1.0.0/a8c-secrets-aarch64-apple-darwin-1.0.0" ]]
	[[ "$output" =~ "checksum: 2b59604261053d2b57a805c53e3b727c43b750e821b587c0492dee7f717bab24" ]]
}

@test "Linux x86_64 resolves to the linux-gnu asset and checksum" {
	plan_for Linux x86_64
	[ "$status" -eq 0 ]
	[[ "$output" =~ "target:   x86_64-unknown-linux-gnu" ]]
	[[ "$output" =~ "checksum: b8fd670c430843ff5af954a85903dc1726d5ca8e3294f725e5e521ac86683bf7" ]]
}

@test "Windows x86_64 resolves to the .exe asset and checksum" {
	plan_for MINGW64_NT-10.0 x86_64
	[ "$status" -eq 0 ]
	[[ "$output" =~ "target:   x86_64-pc-windows-gnu" ]]
	[[ "$output" =~ "asset:    a8c-secrets-x86_64-pc-windows-gnu-1.0.0.exe" ]]
	[[ "$output" =~ "checksum: fd58cc1f7330de1078042ad1cb7afcb127ac66e8de840f202b03b70fd829b086" ]]
}

@test "unsupported architecture exits 2" {
	plan_for Linux riscv64
	[ "$status" -eq 2 ]
	[[ "$output" =~ "Unsupported platform" ]]
}

@test "unsupported operating system exits 2" {
	plan_for Plan9 x86_64
	[ "$status" -eq 2 ]
	[[ "$output" =~ "Unsupported platform" ]]
}

@test "a resolvable target without a pinned checksum is refused" {
	# macOS Intel resolves to a valid triple, but a8c-secrets 1.0.0 publishes no
	# x86_64-apple-darwin asset, so no checksum is pinned for it.
	plan_for Darwin x86_64
	[ "$status" -eq 2 ]
	[[ "$output" =~ "No pinned checksum" ]]
}
