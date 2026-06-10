#!/usr/bin/env bash
set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: $0 <sql-file>"
  exit 1
fi

fail=0

check() {
  local pattern="$1"
  local message="$2"
  if grep -Eiq "$pattern" "$FILE"; then
    echo "[FAIL] $message"
    fail=1
  fi
}

check 'select[[:space:]]+\*' 'SELECT * is forbidden'
check 'delete[[:space:]]+from[[:space:]]+[a-zA-Z0-9_]+[[:space:]]*;' 'DELETE without WHERE is forbidden'
check 'update[[:space:]]+[a-zA-Z0-9_]+[[:space:]]+set[[:space:]].*;' 'Review UPDATE statements manually; ensure WHERE exists'
check 'drop[[:space:]]+(table|column|database)' 'DROP requires explicit approval'
check 'truncate[[:space:]]+table' 'TRUNCATE requires explicit approval'

if [[ "$fail" -eq 1 ]]; then
  echo "SQL safety check failed."
  exit 2
fi

echo "SQL safety check passed."
