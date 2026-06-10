#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGES_DIR="${1:-$ROOT/openspec/changes}"

if [[ ! -d "$CHANGES_DIR" ]]; then
  echo "Usage: $0 [openspec/changes]" >&2
  exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

extract_scope() {
  local change="$1"
  local file="$change/proposal.md"
  [[ -f "$file" ]] || return 0

  awk -v change_name="$(basename "$change")" '
    /^## (Impact Scope|影响范围)/ { in_scope=1; next }
    in_scope && /^## / { in_scope=0 }
    in_scope && /^[[:space:]]*affected_(files|tables|apis|pages|agents):/ {
      key=$1
      sub(/:$/, "", key)
      current=key
      next
    }
    in_scope && /^[[:space:]]*-[[:space:]]*/ && current != "" {
      value=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value != "" && value != "none") {
        print current "\t" value "\t" change_name
      }
    }
  ' "$file"
}

while IFS= read -r change; do
  extract_scope "$change"
done < <(find "$CHANGES_DIR" -mindepth 1 -maxdepth 1 -type d | sort) > "$TMP_FILE"

conflicts=0

while IFS=$'\t' read -r key value changes; do
  count="$(printf '%s\n' "$changes" | tr ',' '\n' | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" -gt 1 ]]; then
    printf '[WARN] %s %s touched by multiple changes: %s\n' "$key" "$value" "$changes"
    conflicts=$((conflicts + 1))
  fi
done < <(
  awk -F '\t' '
    {
      map[$1 FS $2] = map[$1 FS $2] ? map[$1 FS $2] "," $3 : $3
    }
    END {
      for (key in map) {
        split(key, parts, FS)
        print parts[1] "\t" parts[2] "\t" map[key]
      }
    }
  ' "$TMP_FILE" | sort
)

if [[ "$conflicts" -gt 0 ]]; then
  printf 'OpenSpec conflict check completed with warnings. conflicts=%s\n' "$conflicts"
else
  printf 'OpenSpec conflict check passed. conflicts=0\n'
fi
