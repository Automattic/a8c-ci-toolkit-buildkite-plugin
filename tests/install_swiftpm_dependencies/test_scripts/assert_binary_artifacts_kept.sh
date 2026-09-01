#!/bin/bash -eu

set -o pipefail

# The fixture's binary target must survive the cache save, so a later resolution in the same job
# reuses it instead of downloading it again. `tests/test_install_swiftpm_dependencies.bats` pins
# this against stubs; here it runs against real `xcodebuild`/`swift`.

SPM_CACHE_LOCATION="${HOME}/Library/Caches/org.swift.swiftpm"
ARTIFACTS_LOCATION="${SPM_CACHE_LOCATION}/artifacts"

echo "--- :mag: Verify binary artifacts survived the cache save"

if [[ ! -d "${ARTIFACTS_LOCATION}" ]]; then
  echo "Expected ${ARTIFACTS_LOCATION} to exist after resolving a package with a binary target."
  exit 1
fi

if ! find "${ARTIFACTS_LOCATION}" -type f -name '*EventHorizon*' | grep -q .; then
  echo "Expected the fixture's binary artifact in ${ARTIFACTS_LOCATION}. Found:"
  ls -la "${ARTIFACTS_LOCATION}"
  exit 1
fi

echo "Binary artifacts are still in ${ARTIFACTS_LOCATION}."
