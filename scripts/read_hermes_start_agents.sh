#!/usr/bin/env bash
# Print 1 when vars.yml enables gateway start, else 0.
# START_HERMES_AGENTS env var overrides vars.yml when set to 0 or 1.

set -euo pipefail

if [[ -n "${START_HERMES_AGENTS:-}" ]]; then
  echo "$START_HERMES_AGENTS"
  exit 0
fi

vars_file="${1:-vars.yml}"
if [[ -f "$vars_file" ]] && grep -qE '^\s*hermes_start_agents:\s*false\b' "$vars_file"; then
  echo 0
else
  echo 1
fi
