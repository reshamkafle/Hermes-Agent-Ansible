#!/usr/bin/env bash
#
# Deploy all Hermes Agent playbooks to this machine (localhost only).
# Order: deploy_hermes.yml -> deploy_investment.yml -> deploy_news.yml -> deploy_digest.yml
#
# Usage:
#   ./deploy_local.sh
#   START_HERMES_AGENTS=1 ./deploy_local.sh   # also start workspace daemons (default: off)
#
# Prerequisites:
#   - ansible-playbook installed on this machine
#   - vars.yml configured (copy from vars.example..yml)
#   - macOS: Homebrew installed (playbooks install Ollama, git, node, tmux via brew)
#
# For remote hosts, use deploy_all.sh instead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INVENTORY="localhost,"
START_HERMES_AGENTS="${START_HERMES_AGENTS:-0}"

EXTRA_PLAYBOOK_ARGS=(
  -i "$INVENTORY"
  -c local
  -e ansible_become=false
)

if [[ "$START_HERMES_AGENTS" != "1" ]]; then
  EXTRA_PLAYBOOK_ARGS+=(--skip-tags hermes_agents)
  EXTRA_PLAYBOOK_ARGS+=(-e hermes_start_agents=false)
fi

PLAYBOOKS=(
  "deploy_hermes.yml"
  "deploy_investment.yml"
  "deploy_news.yml"
  "deploy_digest.yml"
)

if [[ ! -f "vars.yml" ]]; then
  echo "Error: vars.yml not found. Copy vars.example..yml to vars.yml and fill in your secrets."
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook is not installed."
  exit 1
fi

echo "==> Deploying to localhost (this machine)"
echo "==> Hermes agents after deploy: $([[ "$START_HERMES_AGENTS" == "1" ]] && echo 'start' || echo 'skip (set START_HERMES_AGENTS=1 to start)')"
echo

for playbook in "${PLAYBOOKS[@]}"; do
  if [[ ! -f "$playbook" ]]; then
    echo "Error: Playbook '$playbook' not found."
    exit 1
  fi

  echo "==> Running $playbook"
  ansible-playbook \
    "${EXTRA_PLAYBOOK_ARGS[@]}" \
    "$playbook"
  echo
done

echo "==> All playbooks completed successfully on localhost."
