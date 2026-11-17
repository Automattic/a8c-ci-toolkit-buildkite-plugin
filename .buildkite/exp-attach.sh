#!/bin/bash
# Throwaway experiment (do not merge), round 3: attach Slack entries to THIS running step with `step update`,
# to learn if they are delivered when this step finishes and how `if` is evaluated.

attach() { # name, JSON of one notify entry
  local out status=0
  out=$(buildkite-agent step update notify "[$2]" --append 2>&1) || status=$?
  if [[ $status -eq 0 ]]; then echo "EXP $1: ATTACHED"; else echo "EXP $1: REJECTED: $out"; fi
}

attach "t2 slack object" '{"slack": {"channels": ["#mre-tests"], "message": "🧪 T2 (object form, attached with step update): throwaway notify_skipped_steps experiment, please ignore"}}'
attach "t3 slack object + if step.outcome == passed" '{"slack": {"channels": ["#mre-tests"], "message": "🧪 T3 (if step.outcome == passed): this one SHOULD arrive. Throwaway notify_skipped_steps experiment, please ignore"}, "if": "step.outcome == \"passed\""}'
attach "t4 slack object + if step.outcome == hard_failed" '{"slack": {"channels": ["#mre-tests"], "message": "🧪 T4 (if step.outcome == hard_failed): this one should NOT arrive. Throwaway notify_skipped_steps experiment, please ignore"}, "if": "step.outcome == \"hard_failed\""}'
attach "t5 slack object + if build.state == failed" '{"slack": {"channels": ["#mre-tests"], "message": "🧪 T5 (if build.state == failed): should NOT arrive, the build passes. Throwaway notify_skipped_steps experiment, please ignore"}, "if": "build.state == \"failed\""}'
true
