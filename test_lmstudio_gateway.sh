#!/usr/bin/env bash
#
# Smoke test: LM Studio API + configured model, and Hermes gateway health.
# Does not install Hermes, start services, or touch remote hosts.
#
# Prerequisites:
#   - ./deploy_local.sh already run (~/.hermes and gateway service/LaunchAgent)
#   - vars.yml with lmstudio_base_url and lmstudio_model (or lmstudio_model_linux)
#   - LM Studio running with the configured model loaded
#
# Usage:
#   ./test_lmstudio_gateway.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f "vars.yml" ]]; then
  echo "Error: vars.yml not found. Copy vars.example..yml to vars.yml and fill in LM Studio settings."
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook is not installed."
  exit 1
fi

echo "==> LM Studio + Hermes gateway smoke test (localhost only)"
echo "==> Checks: API at lmstudio_base_url, configured model listed, gateway running"
echo

ansible-playbook smoke_test_lmstudio_gateway.yml \
  -i 'localhost,' \
  -c local \
  -e ansible_become=false \
  -e "@${SCRIPT_DIR}/vars.yml"
