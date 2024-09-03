#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../project"

echo "--- :computer: Generate project"
brew install xcodegen
make

# Test the test by actually copying the Package.resolved and seeing if the test fails
echo "--- :computer: Copy Package.resolved fixture"
PROJECT="Demo.xcodeproj"
XCODE_SPM_PATH="$PROJECT/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$XCODE_SPM_PATH"
cp "$TESTS_LOCATION/../package_resolved_fixtures/valid.resolved" "$XCODE_SPM_PATH/Package.resolved"

echo "--- :wrench: Run install_swiftpm_dependencies"
PROJECT=Demo.xcodeproj
LOGS_PATH=logs
set +e
install_swiftpm_dependencies --project $PROJECT 2>&1 | tee "$LOGS_PATH"
CMD_EXIT_STATUS=$?
set -e

if [[ $CMD_EXIT_STATUS -eq 0 ]]; then
  echo "^^^ install_swiftpm_dependencies unexpectedly succeeded without a Package.resolved in the project folder!"
  exit 1
else
  EXPECTED="Unable to find \`Package.resolved\` file ($PROJECT/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)"
  if grep -qF "$EXPECTED" "$LOGS_PATH"; then
    echo "^^^ +++ install_swiftpm_dependencies failed as expected because there is no Package.resolved in the project folder."
  else
    echo "+++ install_swiftpm_dependencies failed, but the message it printed is not what we expected."
    echo "Expected: $EXPECTED"
    echo "Got: $(cat $LOGS_PATH)"
  fi
fi
