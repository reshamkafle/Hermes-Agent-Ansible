#!/usr/bin/env bash
# Print Hermes gateway health diagnostics to stdout.
# Exit 0 when healthy, 1 when a check fails.
#
# Usage: ./scripts/diagnose_gateway.sh [vars.yml]

set -euo pipefail

VARS_FILE="${1:-vars.yml}"
TARGET_HOME="${HOME:-$(eval echo ~"${USER:-$(id -un)}")}"
ISSUES=0

read_yaml_value() {
  local key="$1"
  if [[ ! -f "$VARS_FILE" ]]; then
    echo ""
    return
  fi
  grep -E "^[[:space:]]*${key}:" "$VARS_FILE" | head -1 \
    | sed -E 's/^[^:]*:[[:space:]]*"?([^"#]*)"?.*/\1/' \
    | tr -d '"' \
    | sed 's/[[:space:]]*$//'
}

note_issue() {
  ISSUES=$((ISSUES + 1))
}

LMSTUDIO_BASE_URL="$(read_yaml_value lmstudio_base_url)"
LMSTUDIO_MODEL="$(read_yaml_value lmstudio_model)"
LMSTUDIO_MODEL_LINUX="$(read_yaml_value lmstudio_model_linux)"
LMSTUDIO_API_KEY="$(read_yaml_value hermes_model_api_key)"
LMSTUDIO_BASE_URL="${LMSTUDIO_BASE_URL:-http://127.0.0.1:1234/v1}"

if [[ "$(uname -s)" == "Linux" ]]; then
  LMSTUDIO_EFFECTIVE_MODEL="$LMSTUDIO_MODEL_LINUX"
else
  LMSTUDIO_EFFECTIVE_MODEL="$LMSTUDIO_MODEL"
fi

if [[ -z "$LMSTUDIO_EFFECTIVE_MODEL" ]]; then
  echo "LM Studio model: NOT set in ${VARS_FILE}."
  if [[ "$(uname -s)" == "Linux" ]]; then
    echo "  Fix: Set lmstudio_model_linux in vars.yml (see vars.example..yml)."
  else
    echo "  Fix: Set lmstudio_model in vars.yml (see vars.example..yml)."
  fi
  note_issue
fi

LMSTUDIO_API="${LMSTUDIO_BASE_URL%/}/models"
CURL_AUTH=()
if [[ -n "$LMSTUDIO_API_KEY" ]]; then
  CURL_AUTH=(-H "Authorization: Bearer ${LMSTUDIO_API_KEY}")
fi

echo "=== Hermes gateway diagnostics ==="

if curl -fsS --max-time 5 "${CURL_AUTH[@]}" "$LMSTUDIO_API" >/dev/null 2>&1; then
  echo "LM Studio: OK at ${LMSTUDIO_BASE_URL}"
else
  echo "LM Studio: NOT reachable at ${LMSTUDIO_BASE_URL}."
  echo "  Fix: Run \`lms daemon up\`, \`lms server start\`, then \`lms get ${LMSTUDIO_EFFECTIVE_MODEL}\`."
  note_issue
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  if launchctl print "gui/$(id -u)" >/dev/null 2>&1; then
    echo "macOS GUI session (Aqua): OK — LaunchAgent can load in this session."
  else
    echo "macOS GUI session (Aqua): NOT available — log in to the Mac desktop (not SSH-only)."
    echo "  Fix: com.hermes.gateway uses LimitLoadToSessionType Aqua and needs an active GUI session."
    note_issue
  fi

  if pgrep -f "[h]ermes.*gateway run" >/dev/null 2>&1; then
    echo "Gateway process: running (\`hermes gateway run\`)."
  else
    echo "Gateway process: NOT running — likely crashed on startup."
    echo "  Fix: check ${TARGET_HOME}/.hermes/logs/gateway.stderr.log"
    note_issue
  fi

  echo
  echo "LaunchAgent status:"
  if launchctl print "gui/$(id -u)/com.hermes.gateway" 2>&1; then
    :
  else
    echo "(LaunchAgent com.hermes.gateway is not loaded)"
    note_issue
  fi

  echo
  echo "Recent gateway stderr (last 25 lines):"
  GATEWAY_STDERR="${TARGET_HOME}/.hermes/logs/gateway.stderr.log"
  if [[ -f "$GATEWAY_STDERR" ]]; then
    tail -n 25 "$GATEWAY_STDERR"
  else
    echo "(missing: ${GATEWAY_STDERR})"
  fi
else
  if command -v systemctl >/dev/null 2>&1; then
    SERVICE_STATE="$(systemctl is-active hermes-workspace 2>&1 || true)"
    echo "systemd hermes-workspace: ${SERVICE_STATE}"
    if [[ "$SERVICE_STATE" == "active" ]]; then
      echo "Gateway service: active."
    else
      echo "Gateway service: NOT active — likely crashed on startup."
      echo "  Fix: run \`systemctl status hermes-workspace\` and check the journal below."
      note_issue
    fi

    echo
    echo "Recent gateway journal (last 25 lines):"
    journalctl -u hermes-workspace -n 25 --no-pager 2>&1 || echo "(no journal entries for hermes-workspace)"
  else
    echo "Gateway service: unable to check (systemctl not found)."
    note_issue
  fi
fi

echo "=== End diagnostics ==="

if [[ "$ISSUES" -gt 0 ]]; then
  exit 1
fi

exit 0
