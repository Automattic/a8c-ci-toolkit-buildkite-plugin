#!/usr/bin/env bats

# `tar` runs for real here — the archive is what these assert on — while S3 is stubbed.
# Exclusion patterns are matched by `tar` itself, and the two implementations differ: GNU tar
# anchors `./sub` to the top level, BSD tar (macOS) also matches a nested `sub`. So these only
# pin what both agree on.

SCRIPT="$BATS_TEST_DIRNAME/../bin/save_cache"

setup() {
	TEST_TMP="$(mktemp -d)"
	export CACHE_BUCKET_NAME=test-bucket

	CACHE_DIR="$TEST_TMP/cache"
	mkdir -p "$CACHE_DIR/artifacts" "$CACHE_DIR/manifests"
	echo zip > "$CACHE_DIR/artifacts/One.zip"
	echo json > "$CACHE_DIR/manifests/manifest.json"

	# `save_cache` writes the archive into the working directory and removes it once uploaded.
	WORK_DIR="$TEST_TMP/work"
	mkdir -p "$WORK_DIR"

	UPLOADED="$TEST_TMP/uploaded.tgz"
	export UPLOADED
	AWS_CALLS="$TEST_TMP/aws_calls.txt"
	export AWS_CALLS
	# Whether the key is already in the bucket. Anything but 0 means "not cached, go upload".
	export HEAD_OBJECT_STATUS=1

	STUB_BIN="$TEST_TMP/bin"
	mkdir -p "$STUB_BIN"
	export PATH="$STUB_BIN:$PATH"

	stub aws 'echo "$*" >> "$AWS_CALLS"
	          case "$1 $2" in
	            "s3api head-object") exit "$HEAD_OBJECT_STATUS" ;;
	            "s3api get-bucket-accelerate-configuration") echo "{\"Status\": \"Suspended\"}" ;;
	            "s3 cp") cp "$3" "$UPLOADED" ;;
	          esac'
	stub jq 'cat > /dev/null; echo Suspended'
	stub hash_directory 'echo derived-from-directory'
}

teardown() {
	rm -rf "$TEST_TMP"
}

stub() {
	printf '#!/usr/bin/env bash\nset -eu\n%s\n' "$2" > "$STUB_BIN/$1"
	chmod +x "$STUB_BIN/$1"
}

save_cache() {
	run bash -c "cd '$WORK_DIR' && '$SCRIPT' $*"
}

archived_entries() {
	tar -tzf "$UPLOADED"
}

@test "--exclude keeps the matching directory out of the archive" {
	save_cache "'$CACHE_DIR' a-key --use_relative_path_in_tar --exclude ./artifacts"
	[ "$status" -eq 0 ]

	run archived_entries
	[[ ! "$output" =~ "One.zip" ]]
	[[ "$output" =~ "manifest.json" ]]
}

@test "--exclude is repeatable" {
	save_cache "'$CACHE_DIR' a-key --use_relative_path_in_tar --exclude ./artifacts --exclude ./manifests"
	[ "$status" -eq 0 ]

	run archived_entries
	[[ ! "$output" =~ "One.zip" ]]
	[[ ! "$output" =~ "manifest.json" ]]
}

@test "--exclude also applies when the archive keeps the full path" {
	save_cache "'$CACHE_DIR' a-key --exclude '*/artifacts'"
	[ "$status" -eq 0 ]

	run archived_entries
	[[ ! "$output" =~ "One.zip" ]]
	[[ "$output" =~ "manifest.json" ]]
}

@test "everything is archived when no --exclude is given" {
	save_cache "'$CACHE_DIR' a-key --use_relative_path_in_tar"
	[ "$status" -eq 0 ]

	run archived_entries
	[[ "$output" =~ "One.zip" ]]
	[[ "$output" =~ "manifest.json" ]]
}

@test "flags are accepted before the paths" {
	save_cache "--use_relative_path_in_tar --exclude ./artifacts '$CACHE_DIR' a-key"
	[ "$status" -eq 0 ]

	run archived_entries
	[[ ! "$output" =~ "One.zip" ]]
	[[ "$output" =~ "manifest.json" ]]
}

@test "--force deletes the existing entry first" {
	save_cache "'$CACHE_DIR' a-key --force"
	[ "$status" -eq 0 ]

	run cat "$AWS_CALLS"
	[[ "$output" =~ "s3 rm s3://test-bucket/a-key" ]]
}

@test "no --force leaves the existing entry alone" {
	save_cache "'$CACHE_DIR' a-key"
	[ "$status" -eq 0 ]

	run cat "$AWS_CALLS"
	[[ ! "$output" =~ "s3 rm" ]]
}

@test "a key already in the bucket is not re-uploaded" {
	export HEAD_OBJECT_STATUS=0
	save_cache "'$CACHE_DIR' a-key"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "already cached" ]]

	[ ! -e "$UPLOADED" ]
}

@test "the cache key is derived from the path when omitted" {
	save_cache "'$CACHE_DIR'"
	[ "$status" -eq 0 ]

	run cat "$AWS_CALLS"
	[[ "$output" =~ "derived-from-directory" ]]
}

@test "the pre-flag calling convention still works" {
	# Callers written against the positional form pass a bare boolean where `--force` now goes,
	# or an empty string when they have no flag to pass at all.
	save_cache "'$CACHE_DIR' a-key false --use_relative_path_in_tar"
	[ "$status" -eq 0 ]

	run cat "$AWS_CALLS"
	[[ ! "$output" =~ "s3 rm" ]]

	save_cache "'$CACHE_DIR' another-key ''"
	[ "$status" -eq 0 ]
}

@test "an unexpected argument fails" {
	save_cache "'$CACHE_DIR' a-key surprise"
	[ "$status" -eq 2 ]
	[[ "$output" =~ "Unexpected argument: surprise" ]]
}

@test "--exclude without a pattern fails" {
	save_cache "'$CACHE_DIR' a-key --exclude"
	[ "$status" -ne 0 ]
	[ ! -e "$UPLOADED" ]
}

@test "no path at all fails" {
	save_cache ""
	[ "$status" -eq 1 ]
	[[ "$output" =~ "You must pass the file or directory" ]]
}

@test "--help prints usage and exits 0" {
	save_cache "--help"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "Usage:" ]]
}
