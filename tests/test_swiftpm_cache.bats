#!/usr/bin/env bats

# `restore_swiftpm_cache` and `save_swiftpm_cache` are tested with stubs for the helpers
# that talk to the cache bucket and change the agent's settings. Each stub logs its
# arguments, and the stubbed `save_cache` also lists what it would upload. The real
# upload and download are exercised by the `install_swiftpm_dependencies` tests on CI.

BIN="$BATS_TEST_DIRNAME/../bin"

setup() {
	STUBS="$BATS_TEST_TMPDIR/stubs"
	CALLS="$BATS_TEST_TMPDIR/calls.log"
	mkdir -p "$STUBS"
	export CALLS

	cat > "$STUBS/hash_file" <<-'EOF'
		#!/usr/bin/env bash
		echo "abc123"
	EOF
	cat > "$STUBS/restore_cache" <<-'EOF'
		#!/usr/bin/env bash
		echo "restore_cache $1 in $PWD" >> "$CALLS"
	EOF
	cat > "$STUBS/save_cache" <<-'EOF'
		#!/usr/bin/env bash
		echo "save_cache $2 $3 $4: $(cd "$1" && find . -mindepth 1 -maxdepth 1 | sort | tr '\n' ' ')" >> "$CALLS"
	EOF
	for stub in sudo add_host_to_ssh_known_hosts; do
		printf '#!/usr/bin/env bash\necho "%s $*" >> "$CALLS"\n' "$stub" > "$STUBS/$stub"
	done
	chmod +x "$STUBS"/*

	# `bin/` is on the PATH, as on CI, so `install_swiftpm_dependencies` finds the commands it calls
	export PATH="$STUBS:$BIN:$PATH"
	export HOME="$BATS_TEST_TMPDIR/home"
	export BUILDKITE_PIPELINE_SLUG="my-pipeline"
	mkdir -p "$HOME"

	cd "$BATS_TEST_TMPDIR"
	echo '{}' > Package.resolved
}

@test "both commands require --package-resolved" {
	run "$BIN/restore_swiftpm_cache"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "'--package-resolved' is required" ]]

	run "$BIN/save_swiftpm_cache" --artifacts .build
	[ "$status" -eq 1 ]
	[[ "$output" =~ "'--package-resolved' is required" ]]
}

@test "both commands fail on a missing Package.resolved" {
	run "$BIN/restore_swiftpm_cache" --package-resolved nope.resolved
	[ "$status" -eq 1 ]
	[[ "$output" =~ "unable to find" ]]

	run "$BIN/save_swiftpm_cache" --package-resolved nope.resolved
	[ "$status" -eq 1 ]
	[[ "$output" =~ "unable to find" ]]
}

@test "both commands reject unknown options and missing values" {
	run "$BIN/restore_swiftpm_cache" --nope
	[ "$status" -eq 1 ]
	[[ "$output" =~ "unknown option '--nope'" ]]

	run "$BIN/save_swiftpm_cache" --package-resolved
	[ "$status" -eq 1 ]
	[[ "$output" =~ "missing value for '--package-resolved'" ]]
}

@test "restore without --artifacts restores only the shared cache, then sets up SSH" {
	run "$BIN/restore_swiftpm_cache" --package-resolved Package.resolved
	[ "$status" -eq 0 ]
	run cat "$CALLS"
	[ "${lines[0]}" = "restore_cache my-pipeline-spm-cache-abc123 in $HOME/Library/Caches/org.swift.swiftpm" ]
	[ "${lines[1]}" = "sudo defaults write com.apple.dt.Xcode IDEPackageSupportUseBuiltinSCM YES" ]
	[ "${lines[2]}" = "add_host_to_ssh_known_hosts bitbucket.org" ]
	[ "${lines[3]}" = "add_host_to_ssh_known_hosts github.com" ]
	[ "${#lines[@]}" -eq 4 ]
}

@test "restore with --artifacts also restores the binary frameworks into that directory" {
	run "$BIN/restore_swiftpm_cache" --package-resolved Package.resolved --artifacts DerivedData/SourcePackages
	[ "$status" -eq 0 ]
	[ -d DerivedData/SourcePackages ]
	run grep restore_cache "$CALLS"
	[ "${lines[1]}" = "restore_cache my-pipeline-spm-artifacts-v1-abc123 in $BATS_TEST_TMPDIR/DerivedData/SourcePackages" ]
}

@test "restore with --artifacts leaves a directory that already has a workspace state alone" {
	mkdir -p .build
	echo '{}' > .build/workspace-state.json
	run "$BIN/restore_swiftpm_cache" --package-resolved Package.resolved --artifacts .build
	[ "$status" -eq 0 ]
	[[ "$output" =~ "already has a \`workspace-state.json\`" ]]
	run grep -c restore_cache "$CALLS"
	[ "$output" = "1" ]
}

@test "save drops checkouts and artifacts from the shared cache before saving it" {
	local spm_cache="$HOME/Library/Caches/org.swift.swiftpm"
	mkdir -p "$spm_cache/checkouts" "$spm_cache/artifacts" "$spm_cache/repositories"
	run "$BIN/save_swiftpm_cache" --package-resolved Package.resolved
	[ "$status" -eq 0 ]
	run cat "$CALLS"
	[ "${lines[0]}" = "save_cache my-pipeline-spm-cache-abc123 false --use_relative_path_in_tar: ./repositories " ]
	[ "${#lines[@]}" -eq 1 ]
}

@test "save with --artifacts uploads only the artifacts folder and the workspace state" {
	mkdir -p .build/artifacts/sentry .build/checkouts .build/debug
	echo '{}' > .build/workspace-state.json
	echo 'framework' > .build/artifacts/sentry/Sentry.zip
	run "$BIN/save_swiftpm_cache" --package-resolved Package.resolved --artifacts .build
	[ "$status" -eq 0 ]
	run grep spm-artifacts "$CALLS"
	[ "$output" = "save_cache my-pipeline-spm-artifacts-v1-abc123 false --use_relative_path_in_tar: ./artifacts ./workspace-state.json " ]
	# The source directory is untouched
	[ -f .build/artifacts/sentry/Sentry.zip ]
}

@test "save with --artifacts skips a directory with no binary frameworks" {
	mkdir -p .build
	echo '{}' > .build/workspace-state.json
	run "$BIN/save_swiftpm_cache" --package-resolved Package.resolved --artifacts .build
	[ "$status" -eq 0 ]
	[[ "$output" =~ "No binary frameworks to save" ]]
	run grep -c save_cache "$CALLS"
	[ "$output" = "1" ]
}

# `install_swiftpm_dependencies --artifacts`, with `xcodebuild` and `swift` stubbed too

stub_resolvers() {
	for tool in xcodebuild swift; do
		printf '#!/usr/bin/env bash\necho "%s $*" >> "$CALLS"\n' "$tool" > "$STUBS/$tool"
	done
	chmod +x "$STUBS/xcodebuild" "$STUBS/swift"
}

@test "install --use-spm --artifacts resolves into that directory and caches it" {
	stub_resolvers
	run "$BIN/install_swiftpm_dependencies" --use-spm --artifacts .build
	[ "$status" -eq 0 ]
	run grep -E "^(swift|restore_cache .*artifacts)" "$CALLS"
	[ "${lines[0]}" = "restore_cache my-pipeline-spm-artifacts-v1-abc123 in $BATS_TEST_TMPDIR/.build" ]
	[ "${lines[1]}" = "swift package resolve --scratch-path .build" ]
}

@test "install --artifacts works before or after the mode option" {
	stub_resolvers
	mkdir -p App.xcworkspace/xcshareddata/swiftpm
	echo '{}' > App.xcworkspace/xcshareddata/swiftpm/Package.resolved
	run "$BIN/install_swiftpm_dependencies" --artifacts DerivedData/SourcePackages --workspace App.xcworkspace
	[ "$status" -eq 0 ]
	run grep "^xcodebuild" "$CALLS"
	[ "$output" = "xcodebuild -workspace App.xcworkspace -resolvePackageDependencies -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath DerivedData/SourcePackages -list" ]
}

@test "install without --artifacts resolves and caches as before" {
	stub_resolvers
	run "$BIN/install_swiftpm_dependencies" --use-spm
	[ "$status" -eq 0 ]
	run grep -c "spm-artifacts" "$CALLS"
	[ "$output" = "0" ]
	run grep "^swift" "$CALLS"
	[ "$output" = "swift package resolve" ]
}

@test "install rejects an unknown option" {
	run "$BIN/install_swiftpm_dependencies" --use-spm --nope
	[ "$status" -eq 2 ]
	[[ "$output" =~ "Unexpected extra arguments: --nope" ]]
}
