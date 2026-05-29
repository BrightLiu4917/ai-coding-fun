#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT/templates/agent/AGENT.md"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/new-agent.sh [--dry-run] <agent-name> "<中文角色名>" "<中文职责描述>"

Examples:
  bash scripts/new-agent.sh agent-go "Go 后端开发工程师" "Go 后端实现手册，用于 Gin/GORM 项目..."
  bash scripts/new-agent.sh go "Go 后端开发工程师" "Go 后端实现手册，用于 Gin/GORM 项目..."
USAGE
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

AGENT_NAME="${1:-}"
if [[ "$#" -ge 3 ]]; then
  ROLE_NAME="${2:-}"
  DESCRIPTION="${3:-}"
else
  ROLE_NAME="${1:-}"
  DESCRIPTION="${2:-}"
fi

[[ -n "$AGENT_NAME" && -n "$ROLE_NAME" && -n "$DESCRIPTION" ]] || { usage; exit 1; }
[[ -f "$TEMPLATE" ]] || fail "Missing template: templates/agent/AGENT.md"

if [[ "$AGENT_NAME" != agent-* ]]; then
  AGENT_NAME="agent-$AGENT_NAME"
fi

[[ "$AGENT_NAME" =~ ^agent-[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "Agent name must use agent-* lowercase kebab-case: $AGENT_NAME"

DEST_FILE="$ROOT/agents/$AGENT_NAME.md"

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

if [[ -e "$DEST_FILE" ]]; then
  fail "Agent already exists: agents/$AGENT_NAME.md"
fi

printf '[CREATE] %s\n' "${DEST_FILE#$ROOT/}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Mode: dry-run\n'
  exit 0
fi

mkdir -p "$ROOT/agents"
SAFE_DESCRIPTION="$(escape_sed_replacement "$DESCRIPTION")"
SAFE_ROLE_NAME="$(escape_sed_replacement "$ROLE_NAME")"
sed \
  -e "s/<agent-name>/$AGENT_NAME/g" \
  -e "s|<中文角色名>|$SAFE_ROLE_NAME|g" \
  -e "s|<中文描述：说明何时使用、职责边界、关键约束。路径、命令、技术名保留英文。>|$SAFE_DESCRIPTION|" \
  "$TEMPLATE" > "$DEST_FILE"

printf 'Agent created: %s\n' "${DEST_FILE#$ROOT/}"
