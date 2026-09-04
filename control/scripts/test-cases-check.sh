#!/usr/bin/env bash
set -euo pipefail

# 测试用例检查：test-cases.md 是设计阶段的验收契约。
# 默认校验：文件存在、至少一条用例、与影响范围闭环
#   - affected_apis 非 none  => 必须有异常流用例
#   - affected_pages 非 none => 必须有权限用例，且有空态或错误态用例
# --require-filled（发布审查用）：状态列不得残留“已设计”。

CHANGE_DIR=""
REQUIRE_FILLED=0

for arg in "$@"; do
  case "$arg" in
    --require-filled) REQUIRE_FILLED=1 ;;
    *) CHANGE_DIR="$arg" ;;
  esac
done

if [[ -z "$CHANGE_DIR" || ! -d "$CHANGE_DIR" ]]; then
  echo "Usage: $0 [--require-filled] openspec/changes/<change-id>" >&2
  exit 1
fi

PROPOSAL="$CHANGE_DIR/proposal.md"
CASES="$CHANGE_DIR/test-cases.md"
fail=0

error() {
  printf '[FAIL] %s\n' "$*"
  fail=1
}

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

if [[ ! -f "$CASES" ]]; then
  error "缺少 test-cases.md；验收测试用例必须在设计阶段产出并随 change 确认"
  echo "Test cases check failed."
  exit 2
fi

case_rows="$(grep -cE '^\|[[:space:]]*TC-' "$CASES" || true)"
if [[ "$case_rows" -eq 0 ]]; then
  error "test-cases.md 没有任何用例行（用例ID 须以 TC- 开头）"
fi

if has_scope_item "affected_apis" "$PROPOSAL"; then
  if ! grep -q '异常流' "$CASES"; then
    error "affected_apis 非 none：必须包含异常流用例（参数错误、数据不存在、状态不允许）"
  fi
fi

if has_scope_item "affected_pages" "$PROPOSAL"; then
  if ! grep -q '权限' "$CASES"; then
    error "affected_pages 非 none：必须包含权限用例"
  fi
  if ! grep -Eq '空态|错误态' "$CASES"; then
    error "affected_pages 非 none：必须包含空态或错误态用例"
  fi
fi

if [[ "$REQUIRE_FILLED" -eq 1 ]]; then
  designed="$(grep -E '^\|[[:space:]]*TC-' "$CASES" | grep -c '已设计' || true)"
  if [[ "$designed" -gt 0 ]]; then
    error "仍有 $designed 条用例状态为“已设计”；发布审查前必须回填为 通过/失败"
  fi
fi

if [[ "$fail" -eq 1 ]]; then
  echo "Test cases check failed."
  exit 2
fi

echo "Test cases check passed."
