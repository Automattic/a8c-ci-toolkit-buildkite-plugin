#!/bin/bash -eu

set -o pipefail

"$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../workspace"

brew install xcodegen
make

echo "--- :wrench: Run install_swiftpm_dependencies"
install_swiftpm_dependencies

echo "--- :xcode: Run tests to verify packages have been fetched and are available"
xcodebuild test \
  -scheme Demo \
  -configuration Debug \
  -destination 'platform=iOS Simulator' \
  | xcbeautify
