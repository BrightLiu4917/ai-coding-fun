#!/usr/bin/env bash
set -euo pipefail

CHANGE_DIR="${1:-}"

if [[ -z "$CHANGE_DIR" || ! -d "$CHANGE_DIR" ]]; then
  echo "Usage: $0 openspec/changes/<change-id>" >&2
  exit 1
fi

fail=0
warn=0

error() {
  printf '[FAIL] %s\n' "$*"
  fail=1
}

warning() {
  printf '[WARN] %s\n' "$*"
  warn=1
}

check_file_scope() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  if ! grep -Eq '^## (Impact Scope|影响范围)' "$file"; then
    error "${file}: missing '## 影响范围'"
    return
  fi

  for key in affected_files affected_tables affected_apis affected_pages affected_agents; do
    if ! grep -Eq "^[[:space:]]*${key}:" "$file"; then
      error "${file}: missing ${key}"
    fi
  done

  if grep -Eq '^[[:space:]]*-[[:space:]]*$' "$file"; then
    warning "${file}: contains empty list item; use 'none' when there is no impact"
  fi
}

check_file_scope "$CHANGE_DIR/proposal.md"
check_file_scope "$CHANGE_DIR/design.md"

if [[ "$fail" -eq 1 ]]; then
  echo "Impact check failed."
  exit 2
fi

if [[ "$warn" -eq 1 ]]; then
  echo "Impact check passed with warnings."
else
  echo "Impact check passed."
fi
