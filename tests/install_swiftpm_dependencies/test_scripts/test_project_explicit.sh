#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../project"

echo "--- :computer: Generate project"
brew install xcodegen
make

echo "--- :computer: Copy Package.resolved fixture"
PROJECT="Demo.xcodeproj"
XCODE_SPM_PATH="$PROJECT/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$XCODE_SPM_PATH"
cp "$TESTS_LOCATION/../package_resolved_fixtures/valid.resolved" "$XCODE_SPM_PATH/Package.resolved"

echo "--- :wrench: Run install_swiftpm_dependencies"
install_swiftpm_dependencies --project $PROJECT

"$TESTS_LOCATION/run_tests_with_xcodebuild.sh"
