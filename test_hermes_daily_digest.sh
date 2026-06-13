#!/usr/bin/env bash
#
# Smoke test: run the Hermes daily-morning-digest skill (news + investment
# combined) and verify the Bootstrap HTML digest is produced. Hermes sends the
# digest to Telegram recipients configured in vars.yml (TELEGRAM_SEND_USERS).
#
# Uses the same hermes chat command as the 6 AM LaunchAgent / cron job.
# Does not install Hermes or touch remote hosts.
#
# Prerequisites:
#   - ./deploy_local.sh already run (Hermes CLI, skills, ~/.hermes/.env)
#   - vars.yml with telegram_bot_token, firecrawl_api_key, and recipient IDs
#   - Ollama running with the model from vars.yml
#
# Usage:
#   ./test_hermes_daily_digest.sh
#   SMOKE_TEST_TIMEOUT=3600 ./test_hermes_daily_digest.sh   # timeout in seconds (default 1800)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SMOKE_TEST_TIMEOUT="${SMOKE_TEST_TIMEOUT:-1800}"

if [[ ! -f "vars.yml" ]]; then
  echo "Error: vars.yml not found. Copy vars.example..yml to vars.yml and fill in your secrets."
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook is not installed."
  exit 1
fi

echo "==> Hermes daily digest smoke test (news + investment -> Telegram)"
echo "==> Timeout: ${SMOKE_TEST_TIMEOUT}s (set SMOKE_TEST_TIMEOUT to override)"
echo "==> This runs hermes chat with daily-morning-digest — it may take several minutes."
echo

ansible-playbook smoke_test_hermes_daily_digest.yml \
  -i 'localhost,' \
  -c local \
  -e ansible_become=false \
  -e "@${SCRIPT_DIR}/vars.yml" \
  -e "smoke_test_timeout_seconds=${SMOKE_TEST_TIMEOUT}"
