#!/usr/bin/env bash
#
# Deploy all Hermes Agent playbooks to this machine (localhost only).
# Order: deploy_hermes.yml -> deploy_investment.yml -> deploy_news.yml -> deploy_gold.yml -> deploy_digest.yml
#
# Usage:
#   ./deploy_local.sh
#   START_HERMES_AGENTS=0 ./deploy_local.sh   # skip starting the Hermes gateway
#
# Prerequisites:
#   - ansible-playbook installed on this machine
#   - vars.yml configured (copy from vars.example..yml)
#   - macOS: Homebrew installed (playbooks install git, node via brew; LM Studio via lmstudio.ai/install.sh)
#
# For remote hosts, use deploy_all.sh instead.

set -euo pipefail

resolve_lms_cmd() {
  local ptr="${HOME}/.lmstudio-home-pointer"
  local home="${HOME}/.lmstudio"
  if [[ -f "$ptr" ]]; then
    home="$(tr -d '[:space:]' < "$ptr")"
  fi
  local candidate
  for candidate in \
    "${home}/bin/lms" \
    "${HOME}/.cache/lm-studio/bin/lms" \
    "${HOME}/.lmstudio/bin/lms"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  echo "lms"
}

LMS_CMD="$(resolve_lms_cmd)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INVENTORY="localhost,"
if [[ -f "vars.yml" ]]; then
  VARS_FILE="vars.yml"
elif [[ -f "vars.yaml" ]]; then
  VARS_FILE="vars.yaml"
else
  echo "Error: vars.yml or vars.yaml not found. Copy vars.example..yml to vars.yml and fill in your secrets."
  exit 1
fi

LMSTUDIO_MODEL="$("$SCRIPT_DIR/scripts/read_yaml_value.sh" lmstudio_model "$VARS_FILE")"
LMSTUDIO_MODEL_LINUX="$("$SCRIPT_DIR/scripts/read_yaml_value.sh" lmstudio_model_linux "$VARS_FILE")"
LMSTUDIO_DOWNLOAD_URL="$("$SCRIPT_DIR/scripts/read_yaml_value.sh" lmstudio_model_download_url "$VARS_FILE")"
HERMES_CTX="$("$SCRIPT_DIR/scripts/read_yaml_value.sh" hermes_model_context_length "$VARS_FILE")"
HERMES_CTX="${HERMES_CTX:-65536}"
if [[ "$(uname -s)" == "Linux" ]]; then
  LMSTUDIO_EFFECTIVE_MODEL="$LMSTUDIO_MODEL_LINUX"
else
  LMSTUDIO_EFFECTIVE_MODEL="$LMSTUDIO_MODEL"
fi

START_HERMES_AGENTS="$("$SCRIPT_DIR/scripts/read_hermes_start_agents.sh" "$VARS_FILE")"

EXTRA_PLAYBOOK_ARGS=(
  -i "$INVENTORY"
  -c local
  -e ansible_become=false
)

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
  "deploy_gold.yml"
  "deploy_digest.yml"
)


if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook is not installed."
  exit 1
fi

echo "==> Deploying to localhost (this machine)"
echo "==> Hermes gateway after deploy: $([[ "$START_HERMES_AGENTS" == "1" ]] && echo 'start' || echo 'skip (set hermes_start_agents: true in vars.yml or run ./start_gateway.sh)')"
echo

for playbook in "${PLAYBOOKS[@]}"; do
  if [[ ! -f "$playbook" ]]; then
    echo "Error: Playbook '$playbook' not found."
    exit 1
  fi

  echo "==> Running $playbook"
  if ! ansible-playbook \
    "${EXTRA_PLAYBOOK_ARGS[@]}" \
    "$playbook"; then
    echo
    echo "Error: $playbook failed."
    lms_log="${HOME}/.hermes/logs/lms-get.log"
    lms_load_log="${HOME}/.hermes/logs/lms-load.log"
    if [[ -f "$lms_load_log" ]]; then
      echo "LM Studio load log: $lms_load_log"
      echo "Last 20 lines:"
      tail -n 20 "$lms_load_log"
    elif [[ -f "$lms_log" ]]; then
      echo "LM Studio download log: $lms_log"
      echo "Last 20 lines:"
      tail -n 20 "$lms_log"
    else
      echo "If model download failed, try manually:"
      echo "  source \"${HOME}/.hermes/bin/lmstudio-path.sh\""
      if [[ -n "$LMSTUDIO_DOWNLOAD_URL" ]]; then
        echo "  lms get ${LMSTUDIO_DOWNLOAD_URL} --gguf --yes"
      else
        echo "  lms get <lmstudio_model_download_url from ${VARS_FILE}> --gguf --yes"
      fi
      echo "If model load failed or hung, try:"
      if [[ -n "$LMSTUDIO_EFFECTIVE_MODEL" ]]; then
        echo "  $LMS_CMD load ${LMSTUDIO_EFFECTIVE_MODEL} --context-length ${HERMES_CTX} --yes"
      else
        echo "  $LMS_CMD load <lmstudio_model from ${VARS_FILE}> --context-length ${HERMES_CTX} --yes"
      fi
      echo "  $LMS_CMD ps"
      if [[ "$LMS_CMD" == "lms" ]]; then
        echo "If you see 'command not found', run:"
        echo "  curl -fsSL https://lmstudio.ai/install.sh | bash"
        echo "  ~/.cache/lm-studio/bin/lms bootstrap -y   # macOS GUI install"
        echo "  ~/.lmstudio/bin/lms bootstrap -y            # headless install"
        echo "Then open a new terminal or: export PATH=\"\$HOME/.cache/lm-studio/bin:\$PATH\""
      fi
      echo "Logs after re-run: $lms_load_log or $lms_log"
    fi
    exit 1
  fi
  echo
done

echo "==> All playbooks completed successfully on localhost."

if [[ "$START_HERMES_AGENTS" == "1" ]]; then
  echo
  echo "==> Hermes gateway started."
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "    Check gateway: launchctl print gui/\$(id -u)/com.hermes.gateway"
    echo "    Gateway logs: tail -f ~/.hermes/logs/gateway.stderr.log"
  else
    echo "    Check status: systemctl status hermes-workspace"
  fi
fi
