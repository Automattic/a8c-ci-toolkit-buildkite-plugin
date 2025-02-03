#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../workspace"

echo "--- :computer: Generate project"
brew install xcodegen
make

echo "--- :wrench: Run install_swiftpm_dependencies"
install_swiftpm_dependencies

"$TESTS_LOCATION/run_tests_with_xcodebuild.sh"
