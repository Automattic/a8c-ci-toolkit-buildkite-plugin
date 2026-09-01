#!/usr/bin/env bats

# Pins the cache-payload contract: binary artifacts stay on disk for the rest of the job but
# never reach the tarball. Everything Apple is stubbed, so these run anywhere — the companion
# end-to-end fixtures under `install_swiftpm_dependencies/` cover real `xcodebuild`/`swift`
# behaviour on macOS agents, and `test_save_cache.bats` covers the exclusion itself.

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

	SAVE_CACHE_ARGS="$TEST_TMP/save_cache_args.txt"
	export SAVE_CACHE_ARGS
	stub save_cache 'printf "%s\n" "$@" > "$SAVE_CACHE_ARGS"'

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

@test "the whole cache directory is saved, with the artifacts excluded" {
	run_in_work_dir
	[ "$status" -eq 0 ]

	run cat "$SAVE_CACHE_ARGS"
	[[ "$output" =~ org.swift.swiftpm ]]
	[[ "$output" =~ "--exclude" ]]
	[[ "$output" =~ "./artifacts" ]]
}

@test "a repo with no binary targets is unaffected" {
	stub swift ''
	run_in_work_dir
	[ "$status" -eq 0 ]

	[ ! -e "$SPM_CACHE/artifacts" ]
}

@test "binary artifacts survive a failing cache save" {
	stub save_cache 'exit 1'
	run_in_work_dir
	[ "$status" -ne 0 ]

	# The job continues on a cache-save failure, so the artifacts must survive it.
	[ -f "$SPM_CACHE/artifacts/https___example_com_One_xcframework_zip" ]
}
