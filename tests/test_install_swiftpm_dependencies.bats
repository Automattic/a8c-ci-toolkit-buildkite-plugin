#!/usr/bin/env bats

# Pins the cache-payload contract: binary artifacts stay on disk for the rest of the job but
# never reach the tarball. Everything Apple is stubbed, so these run anywhere — the companion
# end-to-end fixtures under `install_swiftpm_dependencies/` cover real `xcodebuild`/`swift`
# behaviour on macOS agents.

SCRIPT="$BATS_TEST_DIRNAME/../bin/install_swiftpm_dependencies"

setup() {
	TEST_TMP="$(mktemp -d)"
	export HOME="$TEST_TMP/home"
	export BUILDKITE_PIPELINE_SLUG=test-pipeline

	SPM_CACHE="$HOME/Library/Caches/org.swift.swiftpm"
	# What a resolve leaves behind besides the artifacts.
	mkdir -p "$SPM_CACHE/manifests" "$SPM_CACHE/repositories"
	touch "$SPM_CACHE/manifests/manifest.json" "$SPM_CACHE/repositories/some-repo"

	WORK_DIR="$TEST_TMP/work"
	mkdir -p "$WORK_DIR"
	echo '{"pins":[],"version":3}' > "$WORK_DIR/Package.resolved"

	STUB_BIN="$TEST_TMP/bin"
	mkdir -p "$STUB_BIN"
	export PATH="$STUB_BIN:$PATH"

	# `save_cache` records the cache directory's top-level contents at the moment it is called.
	# That listing IS the payload contract — asserting on it needs no tar and no S3.
	SAVED_PAYLOAD="$TEST_TMP/saved_payload.txt"
	export SAVED_PAYLOAD
	stub save_cache 'ls "$1" > "$SAVED_PAYLOAD"'

	stub hash_file 'echo deadbeef'
	stub restore_cache ''
	stub add_host_to_ssh_known_hosts ''
	# The script writes an Xcode default through `sudo`; irrelevant here and unavailable in CI images.
	stub sudo ''
	# Stand in for a resolve that downloads two binary targets into the shared artifacts cache.
	stub swift 'mkdir -p "$HOME/Library/Caches/org.swift.swiftpm/artifacts"
	            echo zip-one > "$HOME/Library/Caches/org.swift.swiftpm/artifacts/https___example_com_One_xcframework_zip"
	            echo zip-two > "$HOME/Library/Caches/org.swift.swiftpm/artifacts/https___example_com_Two_xcframework_zip"'
}

teardown() {
	rm -rf "$TEST_TMP"
}

stub() {
	printf '#!/usr/bin/env bash\nset -eu\n%s\n' "$2" > "$STUB_BIN/$1"
	chmod +x "$STUB_BIN/$1"
}

run_in_work_dir() {
	run bash -c "cd '$WORK_DIR' && '$SCRIPT' --use-spm"
}

@test "downloaded binary artifacts are still on disk after the cache is saved" {
	run_in_work_dir
	[ "$status" -eq 0 ]

	[ -f "$SPM_CACHE/artifacts/https___example_com_One_xcframework_zip" ]
	[ -f "$SPM_CACHE/artifacts/https___example_com_Two_xcframework_zip" ]
	[ "$(cat "$SPM_CACHE/artifacts/https___example_com_One_xcframework_zip")" = "zip-one" ]
}

@test "the saved payload excludes binary artifacts and keeps everything else" {
	run_in_work_dir
	[ "$status" -eq 0 ]

	run cat "$SAVED_PAYLOAD"
	[[ ! "$output" =~ artifacts ]]
	[[ "$output" =~ manifests ]]
	[[ "$output" =~ repositories ]]
}

@test "nothing is left beside the cache once the run finishes" {
	run_in_work_dir
	[ "$status" -eq 0 ]

	# A leftover would be silently re-uploaded by the next run, which saves the whole cache dir.
	[ ! -e "$SPM_CACHE.artifacts-held-aside" ]
}

@test "a repo with no binary targets is unaffected" {
	stub swift ''
	run_in_work_dir
	[ "$status" -eq 0 ]

	[ ! -e "$SPM_CACHE/artifacts" ]
	run cat "$SAVED_PAYLOAD"
	[[ "$output" =~ manifests ]]
	[[ "$output" =~ repositories ]]
}

@test "recovers when an earlier run was killed while artifacts were held aside" {
	# Agents are reused, so a SIGKILL mid-run leaves this behind for the next build to trip over.
	mkdir -p "$SPM_CACHE.artifacts-held-aside"
	echo zip-stale > "$SPM_CACHE.artifacts-held-aside/https___example_com_Stale_xcframework_zip"

	run_in_work_dir
	[ "$status" -eq 0 ]

	[ ! -e "$SPM_CACHE.artifacts-held-aside" ]
	[ ! -e "$SPM_CACHE/artifacts/artifacts" ]
	[ -f "$SPM_CACHE/artifacts/https___example_com_One_xcframework_zip" ]
	[ -f "$SPM_CACHE/artifacts/https___example_com_Stale_xcframework_zip" ]
}

@test "binary artifacts are returned to the cache even when saving fails" {
	stub save_cache 'exit 1'
	run_in_work_dir
	[ "$status" -ne 0 ]

	# The job continues on a cache-save failure, so the artifacts must survive it.
	[ -f "$SPM_CACHE/artifacts/https___example_com_One_xcframework_zip" ]
	[ ! -e "$SPM_CACHE.artifacts-held-aside" ]
}
