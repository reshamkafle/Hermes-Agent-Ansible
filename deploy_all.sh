#!/usr/bin/env bash
#
# Deploy all Hermes Agent playbooks to remote hosts only.
# Order: deploy_hermes.yml -> deploy_investment.yml -> deploy_news.yml -> deploy_digest.yml
#
# Usage:
#   ./deploy_all.sh
#   INVENTORY=hosts.ini ./deploy_all.sh
#   START_HERMES_AGENTS=1 ./deploy_all.sh   # also start the Hermes gateway (default: off)
#
# Prerequisites:
#   - ansible-playbook installed on this control machine
#   - vars.yml configured (copy from vars.example..yml)
#   - inventory file listing remote target host(s) — NOT localhost

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INVENTORY="${INVENTORY:-inventory.ini}"
LOCALHOST_PATTERN='localhost|127\.0\.0\.1'
START_HERMES_AGENTS="${START_HERMES_AGENTS:-0}"

EXTRA_PLAYBOOK_ARGS=()
if [[ "$START_HERMES_AGENTS" == "1" ]]; then
  EXTRA_PLAYBOOK_ARGS+=(-e hermes_start_agents=true)
else
  EXTRA_PLAYBOOK_ARGS+=(--skip-tags hermes_agents)
  EXTRA_PLAYBOOK_ARGS+=(-e hermes_start_agents=false)
fi

PLAYBOOKS=(
  "deploy_hermes.yml"
  "deploy_investment.yml"
  "deploy_news.yml"
  "deploy_digest.yml"
)

if [[ ! -f "$INVENTORY" ]]; then
  echo "Error: Inventory file '$INVENTORY' not found."
  echo "Create an inventory with your remote host(s). This script does not deploy to localhost."
  exit 1
fi

if [[ ! -f "vars.yml" ]]; then
  echo "Error: vars.yml not found. Copy vars.example..yml to vars.yml and fill in your secrets."
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook is not installed."
  exit 1
fi

echo "==> Resolving remote targets from inventory: $INVENTORY"

REMOTE_HOSTS="$(
  ansible -i "$INVENTORY" all --list-hosts 2>/dev/null \
    | tail -n +2 \
    | sed 's/^[[:space:]]*//' \
    | grep -Ev "$LOCALHOST_PATTERN" || true
)"

if [[ -z "$REMOTE_HOSTS" ]]; then
  echo "Error: No remote hosts found. Refusing to run on this machine."
  exit 1
fi

echo "==> Remote hosts:"
echo "$REMOTE_HOSTS" | sed 's/^/    /'
echo "==> Hermes gateway after deploy: $([[ "$START_HERMES_AGENTS" == "1" ]] && echo 'start' || echo 'skip (set START_HERMES_AGENTS=1 to start)')"
echo

for playbook in "${PLAYBOOKS[@]}"; do
  if [[ ! -f "$playbook" ]]; then
    echo "Error: Playbook '$playbook' not found."
    exit 1
  fi

  echo "==> Running $playbook"
  ansible-playbook \
    -i "$INVENTORY" \
    "$playbook" \
    --limit '!localhost,!127.0.0.1' \
    "${EXTRA_PLAYBOOK_ARGS[@]}"
  echo
done

echo "==> All playbooks completed successfully."

if [[ "$START_HERMES_AGENTS" == "1" ]]; then
  echo
  echo "==> Hermes gateway started on remote host(s)."
  echo "    Linux: ssh to the host and run: systemctl status hermes-workspace"
  echo "    macOS: ssh to the host and run: tmux attach -t hermes_ws"
fi
