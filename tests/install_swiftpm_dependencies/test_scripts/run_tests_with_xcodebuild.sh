#!/bin/bash -eu

set -o pipefail

echo "--- :xcode: Run tests to verify packages have been fetched and are available"
xcodebuild test \
  -scheme Demo \
  -configuration Debug \
  -destination 'platform=iOS Simulator' \
  | xcbeautify
