#!/usr/bin/env bash
set -euo pipefail

# Claude Code CLI provider：用本机 claude 命令的无头模式（claude -p）做独立二审。
# 不需要 API key，复用 Claude Code 订阅；每次调用都是全新无状态进程，
# 天然与实现会话隔离，满足二审独立性要求。
#
# 可选配置：
#   REVIEW_CLI_MODEL   指定模型（透传给 claude --model），默认用 CLI 当前配置
#   REVIEW_CLI_ARGS    追加的原样透传参数

INPUT_FILE="${1:-}"

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  printf 'Usage: %s .agent/reviews/review-input.md\n' "$0" >&2
  exit 2
fi

if ! command -v claude >/dev/null 2>&1; then
  printf 'claude CLI 不可用。安装 Claude Code 或改用 REVIEW_PROVIDER=openai-compatible/anthropic。\n' >&2
  exit 127
fi

INSTRUCTION='你是独立二审员。只基于 stdin 提供的审查材料输出审查报告：
- 不要读取其他文件，不要修改任何代码，不要执行命令。
- 严格按材料中「输出格式」章节的结构输出。
- 最后一行必须是 VERDICT: PASS 或 VERDICT: PASS_WITH_RISKS 或 VERDICT: BLOCK。'

ARGS=(-p "$INSTRUCTION")
[[ -n "${REVIEW_CLI_MODEL:-}" ]] && ARGS+=(--model "$REVIEW_CLI_MODEL")
if [[ -n "${REVIEW_CLI_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  ARGS+=(${REVIEW_CLI_ARGS})
fi

exec claude "${ARGS[@]}" < "$INPUT_FILE"
