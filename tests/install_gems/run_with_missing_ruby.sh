#!/usr/bin/env bash

set -euo pipefail

# Runs `install_gems` on a real agent in a directory whose `.ruby-version` asks for a Ruby no
# image has. Pass `--assert` to check the output instead of letting the failure fail the step.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="$REPO_ROOT/bin:$PATH"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
cp "$REPO_ROOT/Gemfile" "$REPO_ROOT/Gemfile.lock" "$work_dir"
echo '0.0.0' > "$work_dir/.ruby-version"
cd "$work_dir"

if [[ "${1:-}" != '--assert' ]]; then
	install_gems
	exit
fi

set +e
output="$(install_gems 2>&1)"
status=$?
set -e

echo "--- :scroll: install_gems output (exit $status)"
echo "$output"

echo "--- :mag: Assertions"
failures=0
pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; failures=$((failures + 1)); }

if [[ $status -ne 0 ]]; then pass 'exits non-zero'; else fail 'exits non-zero'; fi

if [[ "$output" == *"version \`0.0.0' is not installed"* ]]; then
	pass "shows rbenv's own error"
else
	fail "shows rbenv's own error"
fi

if [[ "$output" =~ "Ruby versions installed on this agent:"($'\n'"  "[0-9]+\.[0-9]+\.[0-9]+)+ ]]; then
	pass 'lists at least one installed Ruby'
else
	fail 'lists at least one installed Ruby'
fi

if [[ "$output" != *'cache bucket'* ]]; then
	pass 'stops before touching the cache'
else
	fail 'stops before touching the cache'
fi

exit "$failures"
