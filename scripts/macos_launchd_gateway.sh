#!/usr/bin/env bash
# Start or stop the Hermes gateway LaunchAgent on macOS.
# Mirrors the launchctl recovery logic from upstream Hermes (bootstrap → kickstart,
# retry on unloaded job, detached fallback when launchd cannot manage the domain).
#
# Usage:
#   macos_launchd_gateway.sh stop [target_home]
#   macos_launchd_gateway.sh start [target_home]

set -euo pipefail

ACTION="${1:-}"
TARGET_HOME="${2:-${HOME:-$(eval echo ~"${USER:-$(id -un)}")}}"
LABEL="com.hermes.gateway"
PLIST="${TARGET_HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${TARGET_HOME}/.hermes/logs"
STDOUT_LOG="${LOG_DIR}/gateway.stdout.log"
STDERR_LOG="${LOG_DIR}/gateway.stderr.log"
RUNNER="${TARGET_HOME}/.hermes/bin/hermes-run.sh"

_LAUNCHD_JOB_UNLOADED_EXIT_CODES=" 3 113 125 "
_LAUNCHCTL_DOMAIN_UNSUPPORTED_CODES=" 5 125 "

_code_in_list() {
  local code="$1"
  local list="$2"
  case " ${list} " in
    *" ${code} "*) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_launchd_domain() {
  local uid="$1"
  local gui_domain="gui/${uid}"
  local user_domain="user/${uid}"

  if launchctl print "${gui_domain}/${LABEL}" >/dev/null 2>&1; then
    echo "${gui_domain}"
    return 0
  fi
  if launchctl print "${user_domain}/${LABEL}" >/dev/null 2>&1; then
    echo "${user_domain}"
    return 0
  fi
  if launchctl print "${gui_domain}" >/dev/null 2>&1; then
    echo "${gui_domain}"
    return 0
  fi
  if launchctl print "${user_domain}" >/dev/null 2>&1; then
    echo "${user_domain}"
    return 0
  fi
  if launchctl managername 2>/dev/null | grep -q Aqua; then
    echo "${gui_domain}"
  else
    echo "${user_domain}"
  fi
}

ensure_log_files() {
  mkdir -p "${LOG_DIR}"
  touch "${STDOUT_LOG}" "${STDERR_LOG}"
}

stop_gateway() {
  local uid domain target
  uid="$(id -u)"
  domain="$(resolve_launchd_domain "${uid}")"
  target="${domain}/${LABEL}"

  launchctl bootout "${target}" 2>/dev/null || \
    launchctl bootout "${domain}" "${PLIST}" 2>/dev/null || \
    launchctl unload -w "${PLIST}" 2>/dev/null || true

  local attempt
  for attempt in $(seq 1 15); do
    pgrep -f "[h]ermes.*gateway run" >/dev/null || break
    sleep 1
  done
  pkill -f "[h]ermes.*gateway run" 2>/dev/null || true
  sleep 1
}

spawn_detached_gateway() {
  ensure_log_files
  if [[ ! -x "${RUNNER}" ]]; then
    echo "macos_launchd_gateway: missing ${RUNNER}" >&2
    return 1
  fi

  nohup "${RUNNER}" gateway run --replace \
    >>"${STDOUT_LOG}" 2>>"${STDERR_LOG}" &
  disown || true
  sleep 2
  pgrep -f "[h]ermes.*gateway run" >/dev/null 2>&1
}

start_gateway() {
  local uid domain target rc
  uid="$(id -u)"
  domain="$(resolve_launchd_domain "${uid}")"
  target="${domain}/${LABEL}"

  if [[ ! -f "${PLIST}" ]]; then
    echo "macos_launchd_gateway: missing LaunchAgent plist at ${PLIST}" >&2
    return 1
  fi

  ensure_log_files

  if launchctl print "${target}" >/dev/null 2>&1; then
    if launchctl kickstart -k "${target}" 2>/dev/null; then
      return 0
    fi
    rc=$?
    if ! _code_in_list "${rc}" "${_LAUNCHD_JOB_UNLOADED_EXIT_CODES}"; then
      if _code_in_list "${rc}" "${_LAUNCHCTL_DOMAIN_UNSUPPORTED_CODES}"; then
        echo "macos_launchd_gateway: launchd domain unsupported (exit ${rc}); using detached fallback" >&2
        spawn_detached_gateway
        return $?
      fi
      return "${rc}"
    fi
  fi

  echo "macos_launchd_gateway: loading LaunchAgent definition" >&2
  launchctl bootout "${target}" 2>/dev/null || true
  if ! launchctl bootstrap "${domain}" "${PLIST}"; then
    rc=$?
    if _code_in_list "${rc}" "${_LAUNCHCTL_DOMAIN_UNSUPPORTED_CODES}"; then
      echo "macos_launchd_gateway: launchd bootstrap unsupported (exit ${rc}); using detached fallback" >&2
      spawn_detached_gateway
      return $?
    fi
    return "${rc}"
  fi

  if launchctl kickstart "${target}"; then
    return 0
  fi
  rc=$?
  if _code_in_list "${rc}" "${_LAUNCHCTL_DOMAIN_UNSUPPORTED_CODES}"; then
    echo "macos_launchd_gateway: launchd kickstart unsupported (exit ${rc}); using detached fallback" >&2
    spawn_detached_gateway
    return $?
  fi
  return "${rc}"
}

case "${ACTION}" in
  stop)
    stop_gateway
    ;;
  start)
    start_gateway
    ;;
  *)
    echo "Usage: $0 {start|stop} [target_home]" >&2
    exit 2
    ;;
esac
