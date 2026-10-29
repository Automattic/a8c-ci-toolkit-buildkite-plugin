#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../package"

echo "--- :wrench: Run restore_swiftpm_cache"
restore_swiftpm_cache --package-resolved Package.resolved --artifacts .build

echo "--- :xcode: Run tests, which resolve the packages themselves"
swift test

echo "--- :wrench: Run save_swiftpm_cache"
save_swiftpm_cache --package-resolved Package.resolved --artifacts .build
