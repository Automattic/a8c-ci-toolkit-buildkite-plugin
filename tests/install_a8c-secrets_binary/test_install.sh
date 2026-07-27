#!/usr/bin/env bash

set -euo pipefail

# End-to-end check that `install_a8c-secrets_binary` downloads, checksum-verifies, and
# installs a working `a8c-secrets` on a real agent. Runs on real CI rather than the
# Docker plugin-tester because it needs network access to the GitHub releases CDN.
#
# Installs via `--install-dir` into a throwaway directory so a shared agent's
# `/usr/local/bin` and `$HOME/.local/bin` are left untouched.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="$REPO_ROOT/bin/install_a8c-secrets_binary"

install_dir="$(mktemp -d)"
trap 'rm -rf "$install_dir"' EXIT

# The installer pins a release, so the binary must report that same version. Read the pin
# from the script itself — sourcing it runs nothing, thanks to its `BASH_SOURCE` guard.
# Kept in a subshell: sourcing installs an EXIT trap that would replace the one above.
expected_version="$(
	# shellcheck source=../../bin/install_a8c-secrets_binary
	source "$INSTALLER"
	echo "$A8C_SECRETS_VERSION"
)"

"$INSTALLER" --install-dir "$install_dir"

echo "--- :mag: Verify the installed binary runs"
version="$("$install_dir/a8c-secrets" --version)"
echo "$version"

case "$version" in
	*"$expected_version"*) echo "OK: a8c-secrets $expected_version installed and runnable" ;;
	*)
		echo "Expected a8c-secrets $expected_version, got: $version" >&2
		exit 1
		;;
esac
