#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../workspace"

brew install xcodegen
make

echo "--- :wrench: Run install_swiftpm_dependencies"
install_swiftpm_dependencies

"$(dirname "${BASH_SOURCE[0]}")/run_tests_with_xcodebuild.sh"
