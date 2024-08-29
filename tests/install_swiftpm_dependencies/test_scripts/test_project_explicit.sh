#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../project"

brew install xcodegen
make
# Also resolve packages to generate Package.resolved in expected location
PROJECT=Demo.xcodeproj
xcodebuild -resolvePackageDependencies -project "$PROJECT"

echo "--- :wrench: Run install_swiftpm_dependencies"
install_swiftpm_dependencies --project "$PROJECT"

"$TESTS_LOCATION/run_tests_with_xcodebuild.sh"
