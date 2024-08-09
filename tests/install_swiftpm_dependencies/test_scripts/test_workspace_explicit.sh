#!/bin/bash -eu

set -o pipefail

TESTS_LOCATION="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_PATH=$PATH:"$TESTS_LOCATION/../../../bin"
export PATH=$NEW_PATH

pushd "$TESTS_LOCATION/../workspace"

install_swiftpm_dependencies --workspace Demo.xcworkspace

xcodebuild test \
  -scheme Demo \
  -configuration Debug \
  -destination 'platform=iOS Simulator' \
  | xcbeautify
