#!/usr/bin/env bash
# Read a top-level key from vars.yml or vars.yaml.
# Usage: read_yaml_value.sh <key> [vars_file]
# If vars_file is omitted, uses vars.yml then vars.yaml in the script's repo root.

set -euo pipefail

key="${1:?usage: read_yaml_value.sh <key> [vars_file]}"
vars_file="${2:-}"

if [[ -z "$vars_file" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "${script_dir}/.." && pwd)"
  if [[ -f "${repo_root}/vars.yml" ]]; then
    vars_file="${repo_root}/vars.yml"
  elif [[ -f "${repo_root}/vars.yaml" ]]; then
    vars_file="${repo_root}/vars.yaml"
  else
    echo ""
    exit 0
  fi
fi

if [[ ! -f "$vars_file" ]]; then
  echo ""
  exit 0
fi

grep -E "^[[:space:]]*${key}:" "$vars_file" | head -1 \
  | sed -E 's/^[^:]*:[[:space:]]*"?([^"#]*)"?.*/\1/' \
  | tr -d '"' \
  | sed 's/[[:space:]]*$//'
