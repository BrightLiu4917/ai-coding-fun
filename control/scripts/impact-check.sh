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

# lite 级别门禁：小需求快速通道不允许涉及数据库表或 API 契约，
# 声明了对应影响范围时必须转为完整流程（不带 --lite 重新生成骨架）。
has_scope_item() {
  local key="$1"
  local file="$2"
  [[ -f "$file" ]] || return 1
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

if grep -Eq '^变更级别:[[:space:]]*lite' "$CHANGE_DIR/proposal.md" 2>/dev/null; then
  if has_scope_item "affected_tables" "$CHANGE_DIR/proposal.md"; then
    error "lite 变更不允许涉及数据库表（affected_tables 非 none）；请升级为完整流程"
  fi
  if has_scope_item "affected_apis" "$CHANGE_DIR/proposal.md"; then
    error "lite 变更不允许涉及 API 契约（affected_apis 非 none）；请升级为完整流程"
  fi
fi

if [[ "$fail" -eq 1 ]]; then
  echo "Impact check failed."
  exit 2
fi

if [[ "$warn" -eq 1 ]]; then
  echo "Impact check passed with warnings."
else
  echo "Impact check passed."
fi
