#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../package"

echo "--- :wrench: Run install_swiftpm_dependencies"
install_swiftpm_dependencies --use-spm

echo "--- :xcode: Run tests to verify packages have been fetched and are available"
swift test
