#!/usr/bin/env bash
set -euo pipefail

# 从 control/AGENTS.md（安装到目标项目根的模板，唯一手写源）生成仓库根 AGENTS.md。
# 路径映射（安装视角 -> 仓库视角）：
#   .ai-control/control/  -> control/
#   openspec/             -> control/openspec/   （仅未带前缀的引用）
#   CONTEXT.md / CONTEXT-MAP.md -> control/CONTEXT.md / control/CONTEXT-MAP.md
#
# 用法：
#   bash control/scripts/sync-agents-md.sh          生成/更新仓库根 AGENTS.md
#   bash control/scripts/sync-agents-md.sh --check  只校验是否同步，不写文件

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
SOURCE_FILE="$ROOT/AGENTS.md"
TARGET_FILE="$REPO_ROOT/AGENTS.md"
MODE="${1:-write}"

[[ -f "$SOURCE_FILE" ]] || { echo "缺少源文件: $SOURCE_FILE" >&2; exit 1; }

generate() {
  sed -E \
    -e 's|\.ai-control/control/|control/|g' \
    -e 's|(^\|[^/[:alnum:]])openspec/|\1control/openspec/|g' \
    -e 's|(^\|[^/[:alnum:]])(CONTEXT(-MAP)?\.md)|\1control/\2|g' \
    "$SOURCE_FILE"
}

if [[ "$MODE" == "--check" ]]; then
  if [[ ! -f "$TARGET_FILE" ]]; then
    echo "[FAIL] 缺少仓库根 AGENTS.md，请运行 sync-agents-md.sh 生成" >&2
    exit 2
  fi
  if ! diff -q <(generate) "$TARGET_FILE" >/dev/null; then
    echo "[FAIL] 仓库根 AGENTS.md 与 control/AGENTS.md 不同步；请只修改 control/AGENTS.md 并运行 sync-agents-md.sh" >&2
    diff <(generate) "$TARGET_FILE" | head -20 >&2
    exit 2
  fi
  echo "AGENTS.md sync check passed."
  exit 0
fi

generate > "$TARGET_FILE"
echo "已从 control/AGENTS.md 生成 $TARGET_FILE"
