#!/usr/bin/env bash
#
# Start (or restart) the Hermes gateway without a full redeploy.
#
# Usage:
#   ./start_gateway.sh              # localhost
#   INVENTORY=inventory.ini ./start_gateway.sh   # remote host(s)
#
# macOS: check with  launchctl print gui/$(id -u)/com.hermes.gateway
# Linux: check with   systemctl status hermes-workspace

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INVENTORY="${INVENTORY:-localhost,}"
LOCAL_DEPLOY=false

if [[ "$INVENTORY" == "localhost," || "$INVENTORY" == "localhost" ]]; then
  LOCAL_DEPLOY=true
fi

if [[ ! -f "vars.yml" ]]; then
  echo "Error: vars.yml not found. Copy vars.example..yml to vars.yml and fill in your secrets."
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook is not installed."
  exit 1
fi

EXTRA_ARGS=(
  -i "$INVENTORY"
  start_gateway.yml
)

if [[ "$LOCAL_DEPLOY" == "true" ]]; then
  EXTRA_ARGS+=(-c local -e ansible_become=false)
fi

echo "==> Starting Hermes gateway"
echo "    Note: Telegram may show 'Gateway shutting down' during restart — that is expected."

ANSIBLE_RC=0
if ! ansible-playbook "${EXTRA_ARGS[@]}"; then
  ANSIBLE_RC=1
fi

echo
echo "==> Gateway diagnostics"
DIAG_RC=0
if [[ "$LOCAL_DEPLOY" == "true" ]]; then
  if ! bash "$SCRIPT_DIR/scripts/diagnose_gateway.sh" vars.yml; then
    DIAG_RC=1
  fi
else
  echo "    Run on the target host after SSH:"
  echo "      bash scripts/diagnose_gateway.sh vars.yml"
fi

if [[ "$ANSIBLE_RC" -ne 0 || "$DIAG_RC" -ne 0 ]]; then
  echo
  echo "==> Gateway start FAILED"
  if [[ "$ANSIBLE_RC" -ne 0 ]]; then
    echo "    Ansible playbook failed — see task output above."
  fi
  if [[ "$DIAG_RC" -ne 0 ]]; then
    echo "    Diagnostics found problems — see the report above."
  fi
  echo "    Common causes:"
  echo "      - Ollama not running (check ollama_base_url in vars.yml)"
  echo "      - Gateway crash on startup (~/.hermes/logs/gateway.stderr.log on macOS)"
  echo "      - Not logged into the Mac GUI (LaunchAgent requires an Aqua session)"
  exit 1
fi

echo
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "==> Gateway running as LaunchAgent 'com.hermes.gateway'"
  echo "    Check: launchctl print gui/\$(id -u)/com.hermes.gateway"
  echo "    Logs:  tail -f ~/.hermes/logs/gateway.stderr.log"
else
  echo "==> Gateway running as systemd service 'hermes-workspace'"
  echo "    Status: systemctl status hermes-workspace"
fi
