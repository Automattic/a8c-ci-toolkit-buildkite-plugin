#!/bin/bash

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo "$0 must be sourced"
  exit 1
fi

set -eu

echo "--- :computer: Prepare environment"
TESTS_LOCATION="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_PATH=$PATH:"$TESTS_LOCATION/../../../bin"

export PATH=$NEW_PATH
export TESTS_LOCATION
