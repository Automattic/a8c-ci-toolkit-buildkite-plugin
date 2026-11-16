#!/usr/bin/env bash

set -euo pipefail

# `buildkite-agent` is stubbed: `pipeline upload --dry-run` replays the JSON the test provides, and `step update` and `annotate` are recorded.
# What the real agent does with those calls is Buildkite's behaviour, so the test only pins what the script decides to send.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/bin/notify_skipped_steps"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/stub"
cat > "$WORK_DIR/stub/buildkite-agent" <<'STUB'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "pipeline upload") echo "dry-run" >> "$STUB_LOG"; cat > /dev/null; cat "$STUB_DRY_RUN_JSON" ;;
  "step update") echo "$*" >> "$STUB_LOG"; echo "$4" > "$STUB_DIR/step-update.json" ;;
  "annotate "*|"annotate") echo "$*" >> "$STUB_LOG"; cat > "$STUB_DIR/annotation.md" ;;
  *) echo "unexpected buildkite-agent call: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$WORK_DIR/stub/buildkite-agent"
export PATH="$WORK_DIR/stub:$PATH"
export STUB_DIR="$WORK_DIR" STUB_LOG="$WORK_DIR/calls.log" STUB_DRY_RUN_JSON="$WORK_DIR/dry-run.json"
unset PIPELINE

failures=0
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "ok: $1"; }

# The pipeline file's content only needs the marker, since the dry run is stubbed.
PIPELINE_WITH_MARKER=$'steps:\n  - label: x\n    notify:\n      - github_commit_status: {context: x}\n        even-if-skipped: true\n'

# Usage: run_case <description> <dry-run JSON> [script args...]. Writes `pipeline.yml` ($PIPELINE_YML or the marker one) and sets $status.
run_case() {
  local description="$1" json="$2"
  shift 2
  echo "--- :test_tube: $description"
  rm -f "$STUB_LOG" "$WORK_DIR/step-update.json" "$WORK_DIR/annotation.md"
  touch "$STUB_LOG"
  echo "$json" > "$STUB_DRY_RUN_JSON"
  echo "${PIPELINE_YML:-$PIPELINE_WITH_MARKER}" > "$WORK_DIR/pipeline.yml"
  status=0
  (cd "$WORK_DIR" && "$SCRIPT" "$@") > "$WORK_DIR/output.log" 2>&1 || status=$?
}

assert_status() {
  if [[ "$status" -eq "$1" ]]; then pass "$2"; else fail "$2 (exit status $status, expected $1)"; fi
}
assert_no_update() {
  if [[ ! -e "$WORK_DIR/step-update.json" ]]; then pass "$1"; else fail "$1 (step update was called)"; fi
}
assert_update_equals() {
  local actual
  actual="$(cat "$WORK_DIR/step-update.json" 2>/dev/null || true)"
  if [[ "$actual" == "$1" ]]; then pass "$2"; else fail "$2 (got: $actual)"; fi
}
assert_annotation_has() {
  if grep -qF -- "$1" "$WORK_DIR/annotation.md" 2>/dev/null; then pass "$2"; else fail "$2 (annotation: $(cat "$WORK_DIR/annotation.md" 2>/dev/null || true))"; fi
}

MAC_BUILD='{"label": ":mac: Build", "skip": "No relevant files changed", "notify": [{"github_commit_status": {"context": "Mac Build"}, "even-if-skipped": true}]}'

run_case "A skipped step with the marker gets its status attached to the running step" "{\"steps\": [$MAC_BUILD]}"
assert_status 0 "exits 0"
assert_update_equals '[{"github_commit_status": {"context": "Mac Build"}}]' "step update carries the context only, without the marker"
# shellcheck disable=SC2016 # The backticks are literal Markdown
assert_annotation_has '| :mac: Build | No relevant files changed | `Mac Build` |' "annotation lists the step, the reason and the context"

run_case "A step that is not skipped is left alone" '{"steps": [{"label": "Build", "skip": false, "notify": [{"github_commit_status": {"context": "Build"}, "even-if-skipped": true}]}]}'
assert_status 0 "exits 0"
assert_no_update "no step update"

run_case "The string \"false\" and the empty string run the step too" '{"steps": [{"label": "A", "skip": "false", "notify": [{"github_commit_status": {"context": "A"}, "even-if-skipped": true}]}, {"label": "B", "skip": "", "notify": [{"github_commit_status": {"context": "B"}, "even-if-skipped": true}]}]}'
assert_no_update "no step update"

run_case "A skipped step without the marker is ignored" '{"steps": [{"label": "Build", "skip": "docs only", "notify": [{"github_commit_status": {"context": "Build"}}]}]}'
assert_no_update "no step update"

run_case "skip: true is reported without a reason" '{"steps": [{"label": "Build", "skip": true, "notify": [{"github_commit_status": {"context": "Build"}, "even-if-skipped": true}]}]}'
assert_annotation_has '| Build | no reason given |' "annotation says no reason was given"

run_case "Steps nested in groups are found, and several contexts are all attached" '{"steps": [{"group": "G", "steps": [{"label": "A", "skip": "r", "notify": [{"github_commit_status": {"context": "A"}, "even-if-skipped": true}]}, {"label": "B", "skip": "r", "notify": [{"github_commit_status": {"context": "B1"}, "even-if-skipped": true}, {"slack": "#x"}, {"github_commit_status": {"context": "B2"}, "even-if-skipped": true}]}]}]}'
assert_update_equals '[{"github_commit_status": {"context": "A"}}, {"github_commit_status": {"context": "B1"}}, {"github_commit_status": {"context": "B2"}}]' "all contexts attached, other notify entries ignored"

run_case "A pipe in a reason doesn't break the annotation table" '{"steps": [{"label": "Build", "skip": "a|b", "notify": [{"github_commit_status": {"context": "Build"}, "even-if-skipped": true}]}]}'
assert_annotation_has '| Build | a\|b |' "pipe is escaped"

run_case "A marker without a context is an error" '{"steps": [{"label": "Build", "skip": "r", "notify": [{"github_commit_status": {}, "even-if-skipped": true}]}]}'
assert_status 1 "exits 1"
assert_no_update "no step update"

PIPELINE_YML=$'steps:\n  - label: x\n' run_case "A pipeline without the marker doesn't even run the dry run" '{"steps": []}'
assert_status 0 "exits 0"
if [[ ! -s "$STUB_LOG" ]]; then pass "no buildkite-agent call"; else fail "buildkite-agent was called: $(cat "$STUB_LOG")"; fi

run_case "The pipeline file is found as an argument, in .buildkite/, or through \$PIPELINE" "{\"steps\": [$MAC_BUILD]}" pipeline.yml
assert_status 0 "argument"
mkdir -p "$WORK_DIR/.buildkite" && mv "$WORK_DIR/pipeline.yml" "$WORK_DIR/.buildkite/other.yml"
status=0; rm -f "$WORK_DIR/step-update.json"
(cd "$WORK_DIR" && "$SCRIPT" other.yml) > "$WORK_DIR/output.log" 2>&1 || status=$?
assert_status 0 "looked up in .buildkite/"
status=0; rm -f "$WORK_DIR/step-update.json"
(cd "$WORK_DIR" && PIPELINE=other.yml "$SCRIPT") > "$WORK_DIR/output.log" 2>&1 || status=$?
assert_status 0 "\$PIPELINE"
assert_update_equals '[{"github_commit_status": {"context": "Mac Build"}}]' "still attached"

run_case "A missing pipeline file is an error" '{"steps": []}' does-not-exist.yml
assert_status 1 "exits 1"

if [[ "$failures" -ne 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All notify_skipped_steps tests passed"
