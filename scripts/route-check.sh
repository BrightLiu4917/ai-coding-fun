#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTING="$ROOT/docs/AGENT_ROUTING.md"
AGENTS="$ROOT/AGENTS.md"
fail=0

error() {
  printf '[FAIL] %s\n' "$*"
  fail=1
}

require_in_file() {
  local file="$1"
  local text="$2"
  if ! grep -Fq -- "$text" "$file"; then
    error "Missing '$text' in ${file#$ROOT/}"
  fi
}

[[ -f "$ROUTING" ]] || error "Missing docs/AGENT_ROUTING.md"
[[ -f "$AGENTS" ]] || error "Missing AGENTS.md"

for token in \
  "agent-product" \
  "agent-openspec" \
  "agent-architect" \
  "agent-ui" \
  "agent-web" \
  "agent-api" \
  "agent-java" \
  "agent-dba" \
  "agent-codegen" \
  "agent-test" \
  "agent-security" \
  "agent-performance" \
  "agent-release"; do
  require_in_file "$ROUTING" "$token"
  require_in_file "$AGENTS" "$token"
  [[ -f "$ROOT/agents/$token.md" ]] || error "Missing agents/$token.md"
done

require_in_file "$AGENTS" "docs/AGENT_ROUTING.md"
require_in_file "$ROUTING" "未确认 adapter 时禁止生成"
require_in_file "$ROUTING" "generic adapter"
require_in_file "$ROUTING" "deepv4"

if grep -R "tools/codegen/java-springboot-crud/scripts" "$ROOT/AGENTS.md" "$ROOT/docs" "$ROOT/agents" "$ROOT/README.md" >/dev/null 2>&1; then
  error "Old generic-looking codegen script path is still referenced"
fi

if [[ "$fail" -eq 1 ]]; then
  printf 'Route check failed.\n'
  exit 2
fi

printf 'Route check passed.\n'
