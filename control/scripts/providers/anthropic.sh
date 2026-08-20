#!/usr/bin/env bash
set -euo pipefail

# Anthropic 官方 Messages API provider（Claude 系列模型做独立二审）。
# 配置：REVIEW_BASE_URL 默认 https://api.anthropic.com；REVIEW_API_KEY；REVIEW_MODEL（如 claude-sonnet-5）。
# 失败处理与 openai-compatible 相同：401/402/403 不重试；超时/429/5xx 重试一次。

INPUT_FILE="${1:-}"

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  printf 'Usage: %s .agent/reviews/review-input.md\n' "$0" >&2
  exit 2
fi

REVIEW_BASE_URL="${REVIEW_BASE_URL:-https://api.anthropic.com}"
REVIEW_API_KEY="${REVIEW_API_KEY:-${DEEPV4_API_KEY:-}}"
REVIEW_MODEL="${REVIEW_MODEL:-${DEEPV4_MODEL:-}}"
REVIEW_MAX_TOKENS="${REVIEW_MAX_TOKENS:-8192}"
REVIEW_CONNECT_TIMEOUT_SECONDS="${REVIEW_CONNECT_TIMEOUT_SECONDS:-10}"
REVIEW_TIMEOUT_SECONDS="${REVIEW_TIMEOUT_SECONDS:-180}"

: "${REVIEW_API_KEY:?REVIEW_API_KEY is required}"
: "${REVIEW_MODEL:?REVIEW_MODEL is required, for example claude-sonnet-5}"

if ! command -v curl >/dev/null 2>&1; then
  printf 'curl is required.\n' >&2
  exit 127
fi

if ! command -v node >/dev/null 2>&1; then
  printf 'node is required to build JSON safely.\n' >&2
  exit 127
fi

PAYLOAD_FILE="$(mktemp)"
RESPONSE_FILE="$(mktemp)"
HEADER_FILE="$(mktemp)"
trap 'rm -f "$PAYLOAD_FILE" "$RESPONSE_FILE" "$HEADER_FILE"' EXIT

chmod 600 "$HEADER_FILE"
{
  printf 'x-api-key: %s\n' "$REVIEW_API_KEY"
  printf 'anthropic-version: 2023-06-01\n'
} > "$HEADER_FILE"

export REVIEW_MODEL REVIEW_MAX_TOKENS
node - "$INPUT_FILE" > "$PAYLOAD_FILE" <<'NODE'
const fs = require("fs");
const inputFile = process.argv[2];
const content = fs.readFileSync(inputFile, "utf8");
const payload = {
  model: process.env.REVIEW_MODEL,
  max_tokens: Number(process.env.REVIEW_MAX_TOKENS || "8192"),
  system:
    "你是独立的生产级代码审查者。所有输出必须使用简体中文。不要重写代码，只报告具体风险、缺失确认项和缺失测试。如果证据不足，标记为需要用户确认的问题。输出最后必须单独一行给出结论：VERDICT: PASS 或 VERDICT: PASS_WITH_RISKS 或 VERDICT: BLOCK。",
  messages: [{ role: "user", content }]
};
process.stdout.write(JSON.stringify(payload));
NODE

ENDPOINT="${REVIEW_BASE_URL%/}/v1/messages"
printf 'REVIEW_HTTP_REQUEST: %s\n' "$ENDPOINT" >&2

do_request() {
  curl -sS \
    --connect-timeout "$REVIEW_CONNECT_TIMEOUT_SECONDS" \
    --max-time "$REVIEW_TIMEOUT_SECONDS" \
    -H @"$HEADER_FILE" \
    -H "Content-Type: application/json" \
    -d @"$PAYLOAD_FILE" \
    -o "$RESPONSE_FILE" \
    -w '%{http_code}' \
    "$ENDPOINT" || printf '000'
}

http_code="$(do_request)"

case "$http_code" in
  000|429|5*)
    printf 'REVIEW_RETRY: 首次请求失败（HTTP %s），3 秒后重试一次...\n' "$http_code" >&2
    sleep 3
    http_code="$(do_request)"
    ;;
esac

case "$http_code" in
  2*) ;;
  401)
    printf 'REVIEW_FAILED: HTTP 401 鉴权失败。请检查 REVIEW_API_KEY。\n' >&2
    exit 2
    ;;
  402|403)
    printf 'REVIEW_FAILED: HTTP %s。通常为账户欠费或无权限，请检查账户余额和模型权限。\n' "$http_code" >&2
    exit 2
    ;;
  000)
    printf 'REVIEW_FAILED: 网络错误或超时（已重试一次）。请检查 REVIEW_BASE_URL 和网络连通性。\n' >&2
    exit 2
    ;;
  *)
    printf 'REVIEW_FAILED: HTTP %s（已按需重试）。响应片段：\n' "$http_code" >&2
    head -c 500 "$RESPONSE_FILE" >&2 || true
    printf '\n' >&2
    exit 2
    ;;
esac

node - "$RESPONSE_FILE" <<'NODE'
const fs = require("fs");
const responseFile = process.argv[2];
const text = fs.readFileSync(responseFile, "utf8");
const data = JSON.parse(text);
const block = data.content && data.content.find((c) => c.type === "text");
if (!block || !block.text) {
  process.stdout.write(text);
  process.exit(0);
}
process.stdout.write(block.text);
NODE
