#!/bin/bash -eu

echo "--- :computer: Prepare environment"
TESTS_LOCATION="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_PATH=$PATH:"$TESTS_LOCATION/../../../bin"
export PATH=$NEW_PATH
