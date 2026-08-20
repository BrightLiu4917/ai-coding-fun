#!/usr/bin/env bash
set -euo pipefail

# 规格防漂移检查：从 OpenSpec 声明反向比对代码实现。
#
# 检查两类漂移：
#   1. change/spec 中声明的 API 路径，在代码中找不到（规格声明了但没实现，或实现后改了路径）
#   2. change 中声明的 affected_tables 表名，在代码/迁移文件中找不到
#
# 默认只告警（exit 0），--strict 时发现漂移 exit 2。
# 用法：
#   spec-drift-check.sh [--strict] openspec/changes/<change-id> [代码根目录]

STRICT=0
CHANGE_DIR=""
CODE_ROOT=""
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    *)
      if [[ -z "$CHANGE_DIR" ]]; then CHANGE_DIR="$arg"; else CODE_ROOT="$arg"; fi
      ;;
  esac
done

if [[ -z "$CHANGE_DIR" || ! -d "$CHANGE_DIR" ]]; then
  echo "Usage: $0 [--strict] openspec/changes/<change-id> [code-root]" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
fi
[[ -n "$CODE_ROOT" ]] || CODE_ROOT="$PROJECT_ROOT"

drift=0
checked=0

warn_drift() {
  printf '[DRIFT] %s\n' "$*"
  drift=$((drift + 1))
}

# 在代码中搜索字符串（排除 openspec/、.ai-control/、常见构建产物）
found_in_code() {
  local needle="$1"
  grep -rIl \
    --exclude-dir=openspec --exclude-dir=.ai-control --exclude-dir=.agent \
    --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist \
    --exclude-dir=target --exclude-dir=.claude --exclude-dir=workbuddy-skills \
    -- "$needle" "$CODE_ROOT" >/dev/null 2>&1
}

# 1. API 路径：从 proposal/design/specs 提取 /api/... 形式的路径
while IFS= read -r api_path; do
  [[ -n "$api_path" ]] || continue
  checked=$((checked + 1))
  if ! found_in_code "$api_path"; then
    warn_drift "API 路径在代码中未找到: $api_path"
  fi
done < <(
  grep -rhoE '/api/[a-z0-9/_-]+' "$CHANGE_DIR" 2>/dev/null | sort -u
)

# 2. 表名：从 affected_tables 提取
while IFS= read -r table; do
  [[ -n "$table" && "$table" != "none" ]] || continue
  checked=$((checked + 1))
  if ! found_in_code "$table"; then
    warn_drift "表名在代码/迁移中未找到: $table"
  fi
done < <(
  awk '
    /^[[:space:]]*affected_tables:/ { in_key=1; next }
    in_key && /^[[:space:]]*[a-zA-Z_]+:/ { in_key=0 }
    in_key && /^[[:space:]]*-[[:space:]]*/ {
      item=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", item)
      gsub(/[[:space:]`]/, "", item)
      if (item != "") print item
    }
  ' "$CHANGE_DIR/proposal.md" 2>/dev/null | sort -u
)

if [[ "$checked" -eq 0 ]]; then
  echo "Spec drift check skipped. no API paths or tables declared"
  exit 0
fi

if [[ "$drift" -gt 0 ]]; then
  echo "Spec drift check found $drift drift(s) out of $checked declared item(s)."
  echo "说明：规格声明与代码不一致，可能是未实现、实现后改名或规格过期；请核对后更新规格或代码。"
  [[ "$STRICT" -eq 1 ]] && exit 2
  exit 0
fi

echo "Spec drift check passed. checked=$checked"
