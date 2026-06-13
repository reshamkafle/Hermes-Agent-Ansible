#!/usr/bin/env bash
#
# Send a one-off Telegram message to verify bot token and chat IDs.
# Loads TELEGRAM_* environment variables from vars.yml (same names as Hermes .env).
# Does not install Hermes or touch remote hosts.
#
# Usage:
#   ./test_telegram.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f "vars.yml" ]]; then
  echo "Error: vars.yml not found. Copy vars.example..yml to vars.yml and fill in Telegram settings."
  exit 1
fi

if ! command -v ansible >/dev/null 2>&1; then
  echo "Error: ansible is not installed."
  exit 1
fi

# macOS Python often lacks system CA certs; use certifi when available.
if python3 -m certifi >/dev/null 2>&1; then
  export SSL_CERT_FILE="$(python3 -m certifi)"
  export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
fi

ENV_FILE="$(mktemp)"
trap 'rm -f "$ENV_FILE"' EXIT

echo "==> Loading TELEGRAM_* environment variables from vars.yml"
ansible localhost \
  -i 'localhost,' \
  -c local \
  -m ansible.builtin.template \
  -a "src=${SCRIPT_DIR}/templates/telegram.env.j2 dest=${ENV_FILE} mode=0600" \
  -e "@vars.yml"

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

echo "==> Sending Telegram smoke test message (localhost only, no Hermes install)"
ansible-playbook smoke_test_telegram.yml
