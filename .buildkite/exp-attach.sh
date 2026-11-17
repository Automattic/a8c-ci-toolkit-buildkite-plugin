#!/bin/bash
# Throwaway experiment (do not merge): attach notify entries to THIS running step with `step update`, one call per entry,
# to learn which types the server accepts there, and which ones fire when this step finishes (and how `if` is evaluated).

attach() { # name, JSON of one notify entry
  local out status=0
  out=$(buildkite-agent step update notify "[$2]" --append 2>&1) || status=$?
  if [[ $status -eq 0 ]]; then echo "EXP $1: ATTACHED"; else echo "EXP $1: REJECTED: $out"; fi
}

attach "t1 slack string (default message)" '{"slack": "#mre-tests"}'
attach "t2 slack object" '{"slack": {"channels": ["#mre-tests"], "message": "🧪 T2 (object form, attached with step update): notify_skipped_steps experiment on a throwaway PR, please ignore"}}'
attach "t3 slack object + if step.outcome == passed" '{"slack": {"channels": ["#mre-tests"], "message": "🧪 T3 (if step.outcome == passed): this one SHOULD arrive. Throwaway notify_skipped_steps experiment, please ignore"}, "if": "step.outcome == \"passed\""}'
attach "t4 slack object + if step.outcome == hard_failed" '{"slack": {"channels": ["#mre-tests"], "message": "🧪 T4 (if step.outcome == hard_failed): this one should NOT arrive. Throwaway notify_skipped_steps experiment, please ignore"}, "if": "step.outcome == \"hard_failed\""}'
attach "t5 slack object + if build.state == failed" '{"slack": {"channels": ["#mre-tests"], "message": "🧪 T5 (if build.state == failed): should NOT arrive, the build passes. Throwaway notify_skipped_steps experiment, please ignore"}, "if": "build.state == \"failed\""}'
attach "t6 github_check" '{"github_check": {"name": "exp: github_check via step update"}}'
attach "t7 github_commit_status" '{"github_commit_status": {"context": "exp: github_commit_status via step update"}}'
attach "t8 entry with an unknown extra key (marker) next to slack" '{"slack": "#mre-tests", "even-if-skipped": true}'
true
