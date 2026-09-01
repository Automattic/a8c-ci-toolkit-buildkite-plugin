#!/usr/bin/env bash

set -euo pipefail

# VALIDATION ONLY — this file is not meant to be merged. See the PR description.
#
# The ordinary suite never runs `save_cache`'s tar-and-upload leg on an agent: the
# `install_swiftpm_dependencies` fixtures always hit an existing cache entry and log
# "This file is already cached – skipping upload". So `--exclude` has only ever been
# exercised under GNU tar in the bats container. This runs the real round trip —
# tar, upload, restore — on a macOS agent, with a unique key per build so it cannot hit.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="$PATH:$REPO_ROOT/bin"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

CASE_INDEX=0
FIRST_KEY=

echo "--- :mag: Environment"
bash --version | head -1
tar --version | head -1

fail() {
  echo "❌ $1"
  exit 1
}

make_fixture() {
  local dir=$1
  # `repositories/artifacts` is a decoy: the same basename one level down. GNU tar and bsdtar
  # disagree about whether `./artifacts` reaches it, so its fate is reported, never asserted.
  mkdir -p "$dir/artifacts" "$dir/manifests" "$dir/repositories/artifacts"
  echo excluded-payload > "$dir/artifacts/One.zip"
  echo kept-payload > "$dir/manifests/manifest.json"
  echo nested-payload > "$dir/repositories/artifacts/decoy"
}

# Saves a fresh fixture under a key that cannot already exist, restores it into an empty
# directory, and asserts on what came back. $2 says whether `artifacts/` should have survived.
round_trip() {
  local label=$1 expect_artifacts=$2
  shift 2

  CASE_INDEX=$((CASE_INDEX + 1))
  local key="save-cache-exclude-validation-${BUILDKITE_BUILD_ID:-local}-${CASE_INDEX}"
  [[ -n "$FIRST_KEY" ]] || FIRST_KEY=$key

  local case_dir="$SCRATCH/case-$CASE_INDEX"
  local source_dir="$case_dir/source"
  local restored_dir="$case_dir/restored"
  mkdir -p "$source_dir" "$restored_dir"
  make_fixture "$source_dir"

  echo "--- :package: $label"
  (cd "$case_dir" && save_cache "$source_dir" "$key" --use_relative_path_in_tar "$@")
  (cd "$restored_dir" && restore_cache "$key")

  # A cache miss on restore also exits 0, so prove the round trip happened at all.
  [[ -f "$restored_dir/manifests/manifest.json" ]] ||
    fail "Nothing was restored for '$key' — the archive never made it to the bucket."
  [[ "$(cat "$restored_dir/manifests/manifest.json")" == 'kept-payload' ]] ||
    fail "The restored sibling file does not hold what was saved."

  if [[ "$expect_artifacts" == 'kept' ]]; then
    [[ -f "$restored_dir/artifacts/One.zip" ]] ||
      fail "Without --exclude, 'artifacts/' should be in the archive, and it is not."
    echo "✅ Without --exclude the archive carries 'artifacts/', so the exclusion is what removes it."
  else
    [[ ! -e "$restored_dir/artifacts" ]] ||
      fail "--exclude did not keep 'artifacts/' out of the uploaded archive."
    echo "✅ '--exclude ./artifacts' kept 'artifacts/' out of the archive; 'manifests/' survived."

    if [[ -e "$restored_dir/repositories/artifacts/decoy" ]]; then
      echo "ℹ️  Observed: the nested 'repositories/artifacts' survived — this tar anchors './artifacts'."
    else
      echo "ℹ️  Observed: the nested 'repositories/artifacts' was excluded too — this tar does not anchor './artifacts'."
    fi
  fi
}

round_trip "Round trip with --exclude" excluded --exclude ./artifacts
round_trip "Round trip without --exclude (negative control)" kept

# These only need the parser to accept them, so they reuse a key already uploaded above:
# `save_cache` parses its arguments before it ever asks S3 whether the key exists.
echo "--- :older_man: Pre-flag calling conventions, on this agent's bash"
PARSE_DIR="$SCRATCH/parse"
mkdir -p "$PARSE_DIR"
make_fixture "$PARSE_DIR"

(cd "$PARSE_DIR" && save_cache "$PARSE_DIR" "$FIRST_KEY" false --use_relative_path_in_tar) ||
  fail "A bare 'false' where --force goes is no longer accepted."
echo "✅ 'PATH KEY false --use_relative_path_in_tar' still parses."

(cd "$PARSE_DIR" && save_cache "$PARSE_DIR" "$FIRST_KEY" "") ||
  fail "An empty string where --force goes is no longer accepted — this would break beeper."
echo "✅ 'PATH KEY \"\"' still parses."

echo "--- :no_entry: A genuinely unexpected argument is still rejected"
if UNEXPECTED_OUTPUT=$(cd "$PARSE_DIR" && save_cache "$PARSE_DIR" "$FIRST_KEY" surprise 2>&1); then
  fail "An unrecognised argument was accepted instead of rejected."
fi
grep -q 'Unexpected argument: surprise' <<< "$UNEXPECTED_OUTPUT" ||
  fail "The command failed, but not through its own guard. It said: $UNEXPECTED_OUTPUT"
echo "✅ Rejected through the guard, not by accident."

echo "--- :white_check_mark: Every assertion passed"
