#!/usr/bin/env bats

# These cases cover the argument and environment contract only — the paths that run before any
# macOS-specific tool (codesign, security, xcrun) is invoked — so they are portable to the Linux
# plugin-tester. The actual signing/notarization is exercised on real macOS CI via a consuming repo.

SCRIPT="$BATS_TEST_DIRNAME/../bin/sign_and_notarize"

# Dummy API key env so the cases that should fail *later* (e.g. on a bad entitlements path) get past
# the env check without reaching any macOS tool.
with_dummy_api_key() {
	export APP_STORE_CONNECT_API_KEY_KEY_ID="dummy"
	export APP_STORE_CONNECT_API_KEY_ISSUER_ID="dummy"
	export APP_STORE_CONNECT_API_KEY_KEY="dummy"
}

@test "--help prints usage and exits 0" {
	run "$SCRIPT" --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "usage: sign_and_notarize" ]]
}

@test "no artifact arguments fails" {
	with_dummy_api_key
	run "$SCRIPT"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "at least one artifact" ]]
}

@test "unknown option fails" {
	with_dummy_api_key
	run "$SCRIPT" --nope artifact
	[ "$status" -eq 1 ]
	[[ "$output" =~ "unknown option" ]]
}

@test "--team-id without a value fails" {
	with_dummy_api_key
	run "$SCRIPT" --team-id
	[ "$status" -eq 1 ]
	[[ "$output" =~ "missing value for --team-id" ]]
}

@test "missing API key environment fails" {
	unset APP_STORE_CONNECT_API_KEY_KEY_ID
	unset APP_STORE_CONNECT_API_KEY_ISSUER_ID
	unset APP_STORE_CONNECT_API_KEY_KEY
	run "$SCRIPT" some-artifact
	[ "$status" -eq 2 ]
	[[ "$output" =~ "APP_STORE_CONNECT_API_KEY" ]]
}

@test "missing entitlements file fails before signing" {
	with_dummy_api_key
	run "$SCRIPT" --entitlements /no/such/file.entitlements some-artifact
	[ "$status" -eq 3 ]
	[[ "$output" =~ "entitlements file not found" ]]
}
