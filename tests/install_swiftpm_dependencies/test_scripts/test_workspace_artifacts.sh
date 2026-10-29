#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../workspace"

echo "--- :computer: Generate project"
brew install xcodegen
make

echo "--- :wrench: Run install_swiftpm_dependencies with --artifacts"
install_swiftpm_dependencies --workspace Demo.xcworkspace --artifacts DerivedData/SourcePackages

echo "--- :xcode: Build with automatic package resolution off, to check the packages are where the build looks for them"
xcodebuild build \
  -workspace Demo.xcworkspace \
  -scheme Demo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  | xcbeautify
