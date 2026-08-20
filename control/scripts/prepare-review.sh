#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
fi
REVIEW_DIR="$PROJECT_ROOT/.agent/reviews"
OUTPUT_FILE="${1:-$REVIEW_DIR/review-input.md}"
TEST_LOG="$PROJECT_ROOT/.agent/logs/test.log"
TEST_SUMMARY="$REVIEW_DIR/test-summary.log"

# 新配置文件优先，旧文件兼容
for env_file in "$PROJECT_ROOT/.agent/review.env" "$PROJECT_ROOT/.agent/deepv4.env"; do
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    break
  fi
done

mkdir -p "$REVIEW_DIR"

# 发往外部 API 的 diff 必须排除的敏感文件（密钥、证书、生产配置）。
# 注意：git pathspec 的 **/ 前缀不匹配仓库根目录文件，必须同时给出根目录与嵌套两种形式。
SENSITIVE_EXCLUDES=(
  ':!.env' ':!.env.*' ':!**/.env' ':!**/.env.*'
  ':!*.pem' ':!*.key' ':!*.p12' ':!*.jks' ':!*.keystore'
  ':!**/*.pem' ':!**/*.key' ':!**/*.p12' ':!**/*.jks' ':!**/*.keystore'
  ':!id_rsa*' ':!id_ed25519*' ':!credentials*' ':!secrets*'
  ':!**/id_rsa*' ':!**/id_ed25519*' ':!**/credentials*' ':!**/secrets*'
  ':!*prod*.yml' ':!*prod*.yaml' ':!*prod*.properties'
  ':!**/*prod*.yml' ':!**/*prod*.yaml' ':!**/*prod*.properties'
)
SENSITIVE_UNTRACKED_PATTERN='(^|/)\.env($|\.)|(^|/)(id_rsa|id_ed25519|credentials|secrets)|\.(pem|key|p12|jks|keystore)$|prod[^/]*\.(yml|yaml|properties)$'
# 已跟踪文件 diff 的体积上限（字节），超限截断，避免把超大变更整体外发
DIFF_MAX_BYTES="${REVIEW_DIFF_MAX_BYTES:-${DEEPV4_DIFF_MAX_BYTES:-512000}}"
DIFF_TMP="$(mktemp)"
trap 'rm -f "$DIFF_TMP"' EXIT

if [[ -f "$TEST_LOG" ]]; then
  bash "$ROOT/scripts/summarize-log.sh" "$TEST_LOG" > "$TEST_SUMMARY"
else
  printf 'TEST_LOG_NOT_FOUND: %s\n' "$TEST_LOG" > "$TEST_SUMMARY"
fi

CHANGE_ID="${OPENSPEC_CHANGE_ID:-}"
CHANGE_DIR=""
if [[ -n "$CHANGE_ID" && -d "$PROJECT_ROOT/openspec/changes/$CHANGE_ID" ]]; then
  CHANGE_DIR="$PROJECT_ROOT/openspec/changes/$CHANGE_ID"
fi

# 按影响范围定向组装审查问题：审得少而准，而不是六问全撒网
has_scope_item() {
  local key="$1"
  local file="$CHANGE_DIR/proposal.md"
  [[ -n "$CHANGE_DIR" && -f "$file" ]] || return 1
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
  printf '# 独立二审输入\n\n'
  printf '## 审查目标\n'
  printf '审查当前本地变更的业务逻辑、数据安全、系统安全、API 兼容性、SQL 风险、事务边界和测试缺口。不要重写代码，只输出审查发现。\n\n'

  printf '## 项目上下文\n'
  printf '```text\n'
  printf 'Repository: %s\n' "$PROJECT_ROOT"
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
  git -C "$PROJECT_ROOT" status --short || true
  printf '\n'
  git -C "$PROJECT_ROOT" diff --stat || true
  printf '\n```\n'

  printf '\n## Git Diff\n'
  printf '```diff\n'
  git -C "$PROJECT_ROOT" diff -- . ':!.agent' ':!**/node_modules/**' ':!**/dist/**' ':!**/target/**' "${SENSITIVE_EXCLUDES[@]}" > "$DIFF_TMP" || true
  diff_size="$(wc -c < "$DIFF_TMP" | tr -d ' ')"
  if [[ "$diff_size" -gt "$DIFF_MAX_BYTES" ]]; then
    head -c "$DIFF_MAX_BYTES" "$DIFF_TMP"
    printf '\n# TRUNCATED: diff %s bytes exceeds limit %s bytes (REVIEW_DIFF_MAX_BYTES)\n' "$diff_size" "$DIFF_MAX_BYTES"
  else
    cat "$DIFF_TMP"
  fi
  # grep 无匹配时返回 1，在 set -o pipefail 下会打断脚本，必须兜底
  git -C "$PROJECT_ROOT" ls-files --others --exclude-standard \
    | { grep -Ev '(^|/)(\.agent|node_modules|dist|target|\.git\.bak-[^/]+)(/|$)' || true; } \
    | { grep -Ev "$SENSITIVE_UNTRACKED_PATTERN" || true; } \
    | while IFS= read -r file; do
        [[ -f "$PROJECT_ROOT/$file" ]] || continue
        size="$(wc -c < "$PROJECT_ROOT/$file" | tr -d ' ')"
        if [[ "$size" -gt 200000 ]]; then
          printf '\n# Skipped large untracked file: %s (%s bytes)\n' "$file" "$size"
          continue
        fi
        if file "$PROJECT_ROOT/$file" | grep -Eq 'text|JSON|XML|Java|script|empty|Markdown|UTF-8|ASCII'; then
          printf '\n# Untracked file: %s\n' "$file"
          git -C "$PROJECT_ROOT" diff --no-index -- /dev/null "$file" || true
        else
          printf '\n# Skipped binary untracked file: %s\n' "$file"
        fi
      done
  printf '\n```\n'

  printf '\n## 审查问题\n'
  printf -- '- 是否猜测了业务规则、字段、枚举、权限、状态流或响应格式？\n'
  printf -- '- 高风险行为是否缺少测试或验证步骤？验收用例是否已回填且覆盖异常路径？\n'
  if has_scope_item "affected_tables"; then
    printf -- '- 【数据库】表结构变更是否有 migration/rollback SQL？锁表和迁移窗口风险？历史数据兼容？\n'
    printf -- '- 【数据库】SQL 是否存在无 WHERE 写操作、无 ON 条件 JOIN、租户/软删除条件缺失、索引缺失？\n'
    printf -- '- 【数据库】多表写入是否有事务边界？并发、幂等和重复提交是否安全？\n'
  fi
  if has_scope_item "affected_apis"; then
    printf -- '- 【接口】API 路径、请求、响应、分页、错误码是否破坏既有兼容性？\n'
    printf -- '- 【接口】参数校验、数据不存在、状态不允许等异常路径是否明确且不落 500？\n'
    printf -- '- 【接口】权限、租户和数据可见性是否有缺口？\n'
  fi
  if has_scope_item "affected_pages"; then
    printf -- '- 【前端】加载态、空态、错误态、权限态和重复提交防护是否完整？\n'
    printf -- '- 【前端】字段映射与后端契约是否一致？长整型 ID 是否按字符串处理？\n'
  fi

  printf '\n## 输出格式\n'
  printf '1. 阻塞问题\n'
  printf '2. 重要风险\n'
  printf '3. 需要用户确认的问题\n'
  printf '4. 建议补充的测试\n'
  printf '5. 最后必须单独一行输出机读结论，且只能是以下之一：\n'
  printf '   VERDICT: PASS\n'
  printf '   VERDICT: PASS_WITH_RISKS\n'
  printf '   VERDICT: BLOCK\n'
} > "$OUTPUT_FILE"

# 外发前密钥扫描：命中即中止，除非显式 REVIEW_ALLOW_SECRETS=1（兼容旧 DEEPV4_ALLOW_SECRETS）
ALLOW_SECRETS="${REVIEW_ALLOW_SECRETS:-${DEEPV4_ALLOW_SECRETS:-0}}"
SECRET_PATTERN='AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9_-]{20,}|(api[_-]?key|secret|password|passwd|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}'
if [[ "$ALLOW_SECRETS" != "1" ]] && grep -Eniq "$SECRET_PATTERN" "$OUTPUT_FILE"; then
  printf 'REVIEW_INPUT_BLOCKED: 审查输入疑似包含密钥/凭证，已中止外发。\n' >&2
  printf '命中位置（行号）:\n' >&2
  grep -Enio "$SECRET_PATTERN" "$OUTPUT_FILE" | cut -d: -f1 | sort -un | head -20 | sed 's/^/  line /' >&2
  printf '确认为误报时，可用 REVIEW_ALLOW_SECRETS=1 重新运行。\n' >&2
  rm -f "$OUTPUT_FILE"
  exit 2
fi

printf 'REVIEW_INPUT=%s\n' "$OUTPUT_FILE"
