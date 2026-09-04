#!/usr/bin/env bash
set -euo pipefail

# Codex CLI provider：用本机 codex 命令的非交互模式（codex exec）做独立二审。
# 不需要单独 API key，复用 Codex 订阅；每次调用都是全新会话，
# 与实现会话上下文隔离，满足二审独立性要求。
#
# 说明：diff 可能很大，超出命令行参数长度限制，因此不把材料塞进参数，
# 而是让 codex 读取审查输入文件（绝对路径，位于项目内，沙箱可读）。
#
# 可选配置：
#   REVIEW_CLI_ARGS    追加的原样透传参数（如 --model xxx）

INPUT_FILE="${1:-}"

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  printf 'Usage: %s .agent/reviews/review-input.md\n' "$0" >&2
  exit 2
fi

if ! command -v codex >/dev/null 2>&1; then
  printf 'codex CLI 不可用。安装 Codex CLI 或改用 REVIEW_PROVIDER=openai-compatible/anthropic。\n' >&2
  exit 127
fi

ABS_INPUT="$(cd "$(dirname "$INPUT_FILE")" && pwd)/$(basename "$INPUT_FILE")"

PROMPT="你是独立二审员。读取文件 ${ABS_INPUT}，只基于该文件内容输出审查报告：
- 不要修改任何代码，不要执行除读取该文件外的任何操作。
- 严格按文件中「输出格式」章节的结构输出。
- 最后一行必须是 VERDICT: PASS 或 VERDICT: PASS_WITH_RISKS 或 VERDICT: BLOCK。"

if [[ -n "${REVIEW_CLI_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  EXTRA=(${REVIEW_CLI_ARGS})
  exec codex exec "${EXTRA[@]}" "$PROMPT"
fi

exec codex exec "$PROMPT"
