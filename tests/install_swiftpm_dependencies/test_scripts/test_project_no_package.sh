#!/bin/bash -eu

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/set_up_environment.sh"

echo "--- :computer: Jump to test folder"
pushd "$TESTS_LOCATION/../project"

echo "--- :computer: Generate project"
brew install xcodegen
make

# Notice we do not set up the fixture Package.resolved.
# As such, we expect the call to the plugin to fail.

echo "--- :wrench: Run install_swiftpm_dependencies"
PROJECT=Demo.xcodeproj
LOGS_PATH=logs
set +e
install_swiftpm_dependencies --project $PROJECT 2>&1 | tee "$LOGS_PATH"
CMD_EXIT_STATUS=$?
set -e

EXPECTED="Unable to find \`Package.resolved\` file ($PROJECT/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)"

if [[ $CMD_EXIT_STATUS -eq 0 ]]; then
  echo "+++ :x: install_swiftpm_dependencies unexpectedly succeeded without a Package.resolved in the project folder!"
  echo "Expected: $EXPECTED"
  echo "Got: $(cat $LOGS_PATH)"
  exit 1
else
  if grep -qF "$EXPECTED" "$LOGS_PATH"; then
    echo "^^^ +++"
    echo "+++ :white_check_mark: install_swiftpm_dependencies failed as expected because there is no Package.resolved in the project folder."
  else
    echo "+++ :x: install_swiftpm_dependencies failed, but the message it printed is not what we expected."
    echo "Expected: $EXPECTED"
    echo "Got: $(cat $LOGS_PATH)"
    exit 1
  fi
fi
