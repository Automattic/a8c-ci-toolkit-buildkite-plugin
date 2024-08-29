#!/bin/bash -eu

set -o pipefail

echo "--- :computer: Prepare environment"
TESTS_LOCATION="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_PATH=$PATH:"$TESTS_LOCATION/../../../bin"
export PATH=$NEW_PATH

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../package"

echo "--- :wrench: Run install_swiftpm_dependencies"
install_swiftpm_dependencies --use-spm

echo "--- :xcode: Run tests to verify packages have been fetched and are available"
swift test
