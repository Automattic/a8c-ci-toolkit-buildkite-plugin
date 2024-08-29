#!/bin/bash -eu

set -o pipefail

"$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../project"

brew install xcodegen
make
# Also resolve packages to generate Package.resolved in expected location
PROJECT=Demo.xcodeproj
xcodebuild -resolvePackageDependencies -project "$PROJECT"

echo "--- :wrench: Run install_swiftpm_dependencies"
install_swiftpm_dependencies --project "$PROJECT"

echo "--- :xcode: Run tests to verify packages have been fetched and are available"
xcodebuild test \
  -scheme Demo \
  -configuration Debug \
  -destination 'platform=iOS Simulator' \
  | xcbeautify
