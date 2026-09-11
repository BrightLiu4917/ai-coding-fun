#!/usr/bin/env bash
set -euo pipefail

# 独立二审调度：组装审查输入 -> 调用外部模型 -> 解析 VERDICT 结论。
#
# 配置（.agent/review.env，兼容旧 .agent/deepv4.env 和 DEEPV4_* 变量）：
#   REVIEW_BASE_URL / REVIEW_API_KEY / REVIEW_MODEL   模型端点（OpenAI 兼容或 Anthropic）
#   REVIEW_PROVIDER=openai-compatible|anthropic|claude-cli|codex-cli  内置 provider（默认 openai-compatible）
#   REVIEW_COMMAND='...'                              自定义审查命令（优先于 REVIEW_PROVIDER）
#   REVIEW_MODE=auto|always|never                     触发策略（默认 auto）
#     auto:   lite 变更跳过并记录；其余执行
#     always: 一律执行；never: 一律跳过并记录
#
# 结论解析：审查输出末尾应包含 "VERDICT: PASS | PASS_WITH_RISKS | BLOCK"
#   BLOCK -> 本脚本 exit 2（发布门禁拦截）
#   缺失 VERDICT -> 告警但放行（视为旧格式输出）

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
fi

REVIEW_DIR="$PROJECT_ROOT/.agent/reviews"

abs_path() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *) printf '%s/%s' "$PWD" "$1" ;;
  esac
}

INPUT_FILE="$(abs_path "${1:-$REVIEW_DIR/review-input.md}")"
OUTPUT_FILE="$(abs_path "${2:-$REVIEW_DIR/review-output.md}")"

# 读取配置：新文件优先，旧文件兼容
for env_file in "$PROJECT_ROOT/.agent/review.env" "$PROJECT_ROOT/.agent/deepv4.env"; do
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    break
  fi
done

# 旧变量名兼容：REVIEW_* 未设置时回退 DEEPV4_*
REVIEW_BASE_URL="${REVIEW_BASE_URL:-${DEEPV4_BASE_URL:-}}"
REVIEW_API_KEY="${REVIEW_API_KEY:-${DEEPV4_API_KEY:-}}"
REVIEW_MODEL="${REVIEW_MODEL:-${DEEPV4_MODEL:-}}"
REVIEW_COMMAND="${REVIEW_COMMAND:-${DEEPV4_REVIEW_COMMAND:-}}"
REVIEW_MODE="${REVIEW_MODE:-auto}"
# 主动触发（ai ship --review）优先于任何模式配置：无条件执行
[[ "${REVIEW_FORCED:-0}" == "1" ]] && REVIEW_MODE="always"
REVIEW_PROVIDER="${REVIEW_PROVIDER:-openai-compatible}"
export REVIEW_BASE_URL REVIEW_API_KEY REVIEW_MODEL

mkdir -p "$REVIEW_DIR"

record_skip() {
  local reason="$1"
  printf 'REVIEW_SKIPPED: %s\n' "$reason" | tee "$OUTPUT_FILE"
  printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${OPENSPEC_CHANGE_ID:-unknown}" "$reason" >> "$REVIEW_DIR/review-skip.log"
}

# 未配置：直接跳过，不报错不重试。
# 已配置的三种形态：REVIEW_COMMAND 自定义命令 / API 端点变量 / CLI 型 provider（无需 API 变量）
is_cli_provider=0
case "$REVIEW_PROVIDER" in
  claude-cli|codex-cli) is_cli_provider=1 ;;
esac
if [[ -z "$REVIEW_COMMAND" && -z "$REVIEW_BASE_URL" && "$is_cli_provider" -eq 0 ]]; then
  record_skip "未配置独立二审（.agent/review.env），已跳过；启用方式见使用手册"
  exit 0
fi

# 触发策略
change_is_lite() {
  local change_id="${OPENSPEC_CHANGE_ID:-}"
  [[ -n "$change_id" ]] || return 1
  local proposal="$PROJECT_ROOT/openspec/changes/$change_id/proposal.md"
  [[ -f "$proposal" ]] || return 1
  grep -Eq '^变更级别:[[:space:]]*lite' "$proposal"
}

case "$REVIEW_MODE" in
  never)
    record_skip "REVIEW_MODE=never"
    exit 0
    ;;
  auto)
    if change_is_lite; then
      record_skip "lite 变更按 REVIEW_MODE=auto 跳过独立二审"
      exit 0
    fi
    ;;
  always) ;;
  *)
    echo "未知 REVIEW_MODE: $REVIEW_MODE（可选 auto|always|never）" >&2
    exit 1
    ;;
esac

if [[ ! -f "$INPUT_FILE" ]]; then
  bash "$ROOT/scripts/prepare-review.sh" "$INPUT_FILE" >/dev/null
fi

# 解析审查命令：REVIEW_COMMAND 优先，否则用内置 provider
if [[ -z "$REVIEW_COMMAND" ]]; then
  provider_script="$ROOT/scripts/providers/${REVIEW_PROVIDER}.sh"
  if [[ ! -f "$provider_script" ]]; then
    echo "未找到 provider: $provider_script（REVIEW_PROVIDER=$REVIEW_PROVIDER）" >&2
    exit 1
  fi
  REVIEW_COMMAND="bash $provider_script"
fi

printf 'REVIEW_INPUT=%s\n' "$INPUT_FILE"
printf 'REVIEW_OUTPUT=%s\n' "$OUTPUT_FILE"
printf 'REVIEW_RUNNING: %s\n' "$REVIEW_COMMAND"

# REVIEW_COMMAND 是受信配置；先切到项目根再执行，输入文件走位置参数
cd "$PROJECT_ROOT"
if ! bash -c "$REVIEW_COMMAND \"\$1\"" review-runner "$INPUT_FILE" | tee "$OUTPUT_FILE"; then
  echo "REVIEW_FAILED: 审查命令执行失败（详见上方错误）。" >&2
  echo "  - 二审默认不阻塞交付；修复端点配置后可重跑 ai ship <change-id> --review" >&2
  exit 2
fi

# VERDICT 解析
verdict="$(grep -Eo 'VERDICT:[[:space:]]*(PASS_WITH_RISKS|PASS|BLOCK)' "$OUTPUT_FILE" | tail -1 | sed 's/VERDICT:[[:space:]]*//' || true)"
case "$verdict" in
  BLOCK)
    printf 'REVIEW_VERDICT=BLOCK：存在阻塞问题，禁止交付；修复后重跑 ai ship <id> --review。\n'
    exit 2
    ;;
  PASS_WITH_RISKS)
    printf 'REVIEW_VERDICT=PASS_WITH_RISKS：放行，但输出中的风险必须写入交付说明。\n'
    ;;
  PASS)
    printf 'REVIEW_VERDICT=PASS\n'
    ;;
  *)
    printf 'REVIEW_VERDICT_MISSING: 输出未包含 VERDICT 行，按旧格式放行；建议模型按新格式输出结论。\n'
    ;;
esac

printf 'REVIEW_OUTPUT=%s\n' "$OUTPUT_FILE"
