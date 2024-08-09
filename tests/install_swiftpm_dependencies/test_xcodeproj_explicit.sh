#!/bin/bash -eu

TESTS_LOCATION="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_PATH=$PATH:"$TESTS_LOCATION/../../bin"
export PATH=$NEW_PATH

pushd "$TESTS_LOCATION/xcodeproj"

install_swiftpm_dependencies --project Demo.xcodeproj

xcodebuild test \
  -scheme Demo \
  -configuration Debug \
  -destination 'platform=iOS Simulator' \
  | xcbeautify
