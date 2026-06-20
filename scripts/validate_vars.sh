#!/usr/bin/env bash
# Validate vars.yml / vars.yaml syntax before ansible-playbook runs.
# Usage: ./scripts/validate_vars.sh [vars.yml|vars.yaml]

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
vars_file="${1:-}"

if [[ -z "$vars_file" ]]; then
  if [[ -f "${repo_root}/vars.yml" ]]; then
    vars_file="${repo_root}/vars.yml"
  elif [[ -f "${repo_root}/vars.yaml" ]]; then
    vars_file="${repo_root}/vars.yaml"
  else
    echo "Error: No vars.yml or vars.yaml found in ${repo_root}."
    echo "Copy vars.example..yml to vars.yml and fill in your secrets."
    exit 1
  fi
elif [[ ! "$vars_file" = /* ]]; then
  vars_file="${repo_root}/${vars_file}"
fi

if [[ ! -f "$vars_file" ]]; then
  echo "Error: Vars file not found: ${vars_file}"
  exit 1
fi

errors=0

if grep -q $'\t' "$vars_file"; then
  echo "Error: ${vars_file} contains tab characters. Use spaces only for indentation."
  grep -n $'\t' "$vars_file" | head -5
  errors=1
fi

# Top-level keys must start at column 0 (list items use two spaces before "-").
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ ^# ]] && continue
  if [[ "$line" =~ ^[[:space:]]+[^[:space:]#-] ]]; then
    if [[ ! "$line" =~ ^[[:space:]]+-[[:space:]] ]]; then
      lineno="$(grep -Fn "$line" "$vars_file" | head -1 | cut -d: -f1)"
      echo "Error: ${vars_file}:${lineno}: indented key looks invalid (extra leading space before top-level key?)"
      echo "  ${line}"
      errors=1
    fi
  fi
done < "$vars_file"

if command -v ruby >/dev/null 2>&1; then
  if ! ruby -ryaml -e "YAML.load_file('${vars_file}')" 2>"${repo_root}/.validate_vars.err"; then
    echo "Error: ${vars_file} is not valid YAML:"
    sed 's/^/  /' "${repo_root}/.validate_vars.err"
    errors=1
  fi
  rm -f "${repo_root}/.validate_vars.err"
else
  echo "Warning: ruby not found; skipping full YAML parse check."
fi

if [[ "$errors" -ne 0 ]]; then
  echo
  echo "Fix ${vars_file}, or replace it from the template:"
  echo "  cp vars.example..yml vars.yml"
  exit 1
fi

echo "OK: ${vars_file} is valid YAML."
