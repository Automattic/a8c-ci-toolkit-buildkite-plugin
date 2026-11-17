#!/bin/bash
# Throwaway experiment (do not merge): run the stripping-approach oracle on the real upload agent.
python3 .buildkite/exp/compare.py 2>&1 | sed "s/^/EXP /"
