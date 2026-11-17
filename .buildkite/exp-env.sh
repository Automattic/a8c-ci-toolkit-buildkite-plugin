#!/bin/bash
# Throwaway experiment (do not merge): report what the `upload` agents provide, to compare ways of filtering a pipeline.
echo "EXP agent: $(buildkite-agent --version)"
echo "EXP python3: $(command -v python3) $(python3 --version 2>&1)"
if python3 -c 'import yaml; print("EXP PyYAML", yaml.__version__)' 2>&1; then :; else echo "EXP PyYAML: NOT AVAILABLE"; fi
echo "EXP pip: $(python3 -m pip --version 2>&1 | head -1)"
echo "EXP jq: $(command -v jq || echo none)"

# Does the agent on this queue support the flags the JSON approach needs?
out=$(buildkite-agent pipeline upload --dry-run --no-interpolation --format json 2>&1 <<'Y'
steps:
  - label: "build $VAR"
    command: echo $$KEEP $VAR
    notify:
      - slack: "#c"
        even-if-skipped: true
Y
)
echo "EXP dry-run --no-interpolation exit=$?"
echo "$out" | grep -E '"command"|"label"|even-if-skipped|rror' | head -5 | sed 's/^/EXP   /'
