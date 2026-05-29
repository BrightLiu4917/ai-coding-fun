#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEEPV4_ENV_FILE="$ROOT/.agent/deepv4.env"
REVIEW_DIR="$ROOT/.agent/reviews"
OUTPUT_FILE="${1:-$REVIEW_DIR/deepv4-input.md}"
TEST_LOG="$ROOT/.agent/logs/test.log"
TEST_SUMMARY="$REVIEW_DIR/test-summary.log"

if [[ -f "$DEEPV4_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$DEEPV4_ENV_FILE"
  set +a
fi

mkdir -p "$REVIEW_DIR"

if [[ -f "$TEST_LOG" ]]; then
  bash "$ROOT/scripts/summarize-log.sh" "$TEST_LOG" > "$TEST_SUMMARY"
else
  printf 'TEST_LOG_NOT_FOUND: %s\n' "$TEST_LOG" > "$TEST_SUMMARY"
fi

CHANGE_ID="${OPENSPEC_CHANGE_ID:-}"
CHANGE_DIR=""
if [[ -n "$CHANGE_ID" && -d "$ROOT/openspec/changes/$CHANGE_ID" ]]; then
  CHANGE_DIR="$ROOT/openspec/changes/$CHANGE_ID"
fi

write_file_if_exists() {
  local title="$1"
  local file="$2"

  printf '\n## %s\n' "$title"
  if [[ -f "$file" ]]; then
    printf '```markdown\n'
    sed -n '1,220p' "$file"
    printf '\n```\n'
  else
    printf 'NOT_PROVIDED\n'
  fi
}

{
  printf '# deepv4 审查输入\n\n'
  printf '## 审查目标\n'
  printf '审查当前本地变更的业务逻辑、数据安全、系统安全、API 兼容性、SQL 风险、事务边界和测试缺口。不要重写代码，只输出审查发现。\n\n'

  printf '## 项目上下文\n'
  printf '```text\n'
  printf 'Repository: %s\n' "$ROOT"
  printf 'OpenSpec change: %s\n' "${CHANGE_ID:-NOT_PROVIDED}"
  printf '```\n'

  write_file_if_exists "OpenSpec 提案" "$CHANGE_DIR/proposal.md"
  write_file_if_exists "OpenSpec 设计" "$CHANGE_DIR/design.md"
  write_file_if_exists "OpenSpec 任务" "$CHANGE_DIR/tasks.md"

  printf '\n## 测试摘要\n'
  printf '```text\n'
  sed -n '1,240p' "$TEST_SUMMARY"
  printf '\n```\n'

  printf '\n## Git 变更统计\n'
  printf '```text\n'
  git -C "$ROOT" status --short || true
  printf '\n'
  git -C "$ROOT" diff --stat || true
  printf '\n```\n'

  printf '\n## Git Diff\n'
  printf '```diff\n'
  git -C "$ROOT" diff -- . ':!.agent' ':!**/node_modules/**' ':!**/dist/**' ':!**/target/**' || true
  git -C "$ROOT" ls-files --others --exclude-standard \
    | grep -Ev '(^|/)(\.agent|node_modules|dist|target|\.git\.bak-[^/]+)(/|$)' \
    | while IFS= read -r file; do
        [[ -f "$ROOT/$file" ]] || continue
        size="$(wc -c < "$ROOT/$file" | tr -d ' ')"
        if [[ "$size" -gt 200000 ]]; then
          printf '\n# Skipped large untracked file: %s (%s bytes)\n' "$file" "$size"
          continue
        fi
        if file "$ROOT/$file" | grep -Eq 'text|JSON|XML|Java|script|empty|Markdown|UTF-8|ASCII'; then
          printf '\n# Untracked file: %s\n' "$file"
          git -C "$ROOT" diff --no-index -- /dev/null "$file" || true
        else
          printf '\n# Skipped binary untracked file: %s\n' "$file"
        fi
      done
  printf '\n```\n'

  printf '\n## 审查问题\n'
  printf -- '- 是否猜测了业务规则、字段、枚举、API 路径、权限、状态流或响应格式？\n'
  printf -- '- 是否存在租户、权限、软删除或数据可见性缺口？\n'
  printf -- '- 事务边界、并发、幂等和重复提交是否安全？\n'
  printf -- '- SQL 和数据库变更是否安全、有索引、可回滚，并兼容历史数据？\n'
  printf -- '- API 契约和前端预期是否兼容？\n'
  printf -- '- 高风险行为是否缺少测试或验证步骤？\n'

  printf '\n## 输出格式\n'
  printf '1. 阻塞问题\n'
  printf '2. 重要风险\n'
  printf '3. 需要用户确认的问题\n'
  printf '4. 建议补充的测试\n'
  printf '5. 是否可以进入 Codex 最终审查\n'
} > "$OUTPUT_FILE"

printf 'DEEPV4_INPUT=%s\n' "$OUTPUT_FILE"
