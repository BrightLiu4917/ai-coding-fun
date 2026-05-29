#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-}"

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  printf 'Usage: %s .agent/reviews/deepv4-input.md\n' "$0" >&2
  exit 2
fi

: "${DEEPV4_BASE_URL:?DEEPV4_BASE_URL is required, for example https://api.example.com/v1}"
: "${DEEPV4_API_KEY:?DEEPV4_API_KEY is required}"
: "${DEEPV4_MODEL:?DEEPV4_MODEL is required}"
DEEPV4_CONNECT_TIMEOUT_SECONDS="${DEEPV4_CONNECT_TIMEOUT_SECONDS:-10}"
DEEPV4_TIMEOUT_SECONDS="${DEEPV4_TIMEOUT_SECONDS:-180}"

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
trap 'rm -f "$PAYLOAD_FILE" "$RESPONSE_FILE"' EXIT

node - "$INPUT_FILE" > "$PAYLOAD_FILE" <<'NODE'
const fs = require("fs");
const inputFile = process.argv[2];
const content = fs.readFileSync(inputFile, "utf8");
const payload = {
  model: process.env.DEEPV4_MODEL,
  temperature: Number(process.env.DEEPV4_TEMPERATURE || "0.1"),
  messages: [
    {
      role: "system",
      content:
        "你是独立的生产级代码审查者。所有输出必须使用简体中文。不要重写代码，只报告具体风险、缺失确认项和缺失测试。如果证据不足，标记为需要用户确认的问题。"
    },
    {
      role: "user",
      content
    }
  ]
};
process.stdout.write(JSON.stringify(payload));
NODE

printf 'DEEPV4_HTTP_REQUEST: %s\n' "${DEEPV4_BASE_URL%/}/chat/completions" >&2
printf 'DEEPV4_TIMEOUT_SECONDS: %s\n' "$DEEPV4_TIMEOUT_SECONDS" >&2

curl -fsS \
  --connect-timeout "$DEEPV4_CONNECT_TIMEOUT_SECONDS" \
  --max-time "$DEEPV4_TIMEOUT_SECONDS" \
  -H "Authorization: Bearer ${DEEPV4_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @"$PAYLOAD_FILE" \
  -o "$RESPONSE_FILE" \
  "${DEEPV4_BASE_URL%/}/chat/completions"

node - "$RESPONSE_FILE" <<'NODE'
const fs = require("fs");
const responseFile = process.argv[2];
const text = fs.readFileSync(responseFile, "utf8");
const data = JSON.parse(text);
const choice = data.choices && data.choices[0];
const message = choice && choice.message && choice.message.content;
if (!message) {
  process.stdout.write(text);
  process.exit(0);
}
process.stdout.write(message);
NODE
