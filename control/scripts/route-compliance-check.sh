#!/usr/bin/env bash
set -euo pipefail

CHANGE_DIR="${1:-}"

if [[ -z "$CHANGE_DIR" || ! -d "$CHANGE_DIR" ]]; then
  echo "Usage: $0 openspec/changes/<change-id>" >&2
  exit 1
fi

PROPOSAL="$CHANGE_DIR/proposal.md"
TASKS="$CHANGE_DIR/tasks.md"
fail=0

error() {
  printf '[FAIL] %s\n' "$*"
  fail=1
}

has_scope_item() {
  local key="$1"
  local file="$2"
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key ":" { in_key=1; next }
    in_key && /^[[:space:]]*[a-zA-Z_]+:/ { in_key=0 }
    in_key && /^[[:space:]]*-[[:space:]]*/ {
      item=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", item)
      if (item != "" && item != "none") found=1
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

require_tasks_token() {
  local reason="$1"
  local pattern="$2"
  if ! grep -Eiq "$pattern" "$TASKS"; then
    error "$reason requires tasks.md to mention '$pattern'"
  fi
}

[[ -f "$PROPOSAL" ]] || error "Missing proposal.md"
[[ -f "$TASKS" ]] || error "Missing tasks.md"

if [[ -f "$PROPOSAL" && -f "$TASKS" ]]; then
  if has_scope_item "affected_tables" "$PROPOSAL"; then
    require_tasks_token "affected_tables" "agent-dba|DBA|database|数据库|SQL"
  fi

  if has_scope_item "affected_apis" "$PROPOSAL"; then
    require_tasks_token "affected_apis" "api-contract|API contract|API 契约|接口契约|agent-api"
  fi

  if has_scope_item "affected_pages" "$PROPOSAL"; then
    require_tasks_token "affected_pages" "agent-web|agent-ui|frontend|前端|visual|界面"
  fi

  if has_scope_item "affected_files" "$PROPOSAL"; then
    require_tasks_token "affected_files" "review|审查|验证|test|check"
  fi
fi

if [[ "$fail" -eq 1 ]]; then
  echo "Route compliance check failed."
  exit 2
fi

echo "Route compliance check passed."
