#!/bin/bash -eu

set -o pipefail

# End-to-end check that the plugin's install_a8c_secrets command downloads, checksum-
# verifies, and installs a working a8c-secrets on a real agent. Runs on real CI (not the
# Docker plugin-tester) because it needs network access to the GitHub releases CDN.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="$REPO_ROOT/bin:$PATH"

echo "--- :closed_lock_with_key: Install a8c-secrets via the plugin command"
install_a8c_secrets

echo "--- :mag: Verify the installed binary runs"
# install_a8c_secrets installs to /usr/local/bin or ~/.local/bin but doesn't touch this
# shell's PATH, so add both candidate locations before invoking the binary.
export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"

version="$(a8c-secrets --version)"
echo "$version"

# The command pins a specific release, so the installed binary must report that version.
expected="1.0.0"
case "$version" in
	*"$expected"*) echo "OK: a8c-secrets $expected installed and runnable" ;;
	*)
		echo "Expected a8c-secrets $expected, got: $version" >&2
		exit 1
		;;
esac
