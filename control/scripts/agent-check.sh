#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  REPO_ROOT="$(cd "$ROOT/.." && pwd)"
fi
AGENTS_DIR="$ROOT/agents"
fail=0
count=0

error() {
  printf '[FAIL] %s\n' "$*"
  fail=1
}

warn() {
  printf '[WARN] %s\n' "$*"
}

should_skip_reference() {
  local ref="$1"
  [[ -z "$ref" ]] && return 0
  [[ "$ref" == *"<"* || "$ref" == *">"* ]] && return 0
  [[ "$ref" == *"*"* ]] && return 0
  [[ "$ref" == *"..."* ]] && return 0
  [[ "$ref" == http://* || "$ref" == https://* ]] && return 0
  [[ "$ref" == "如存在" || "$ref" == "如需要" ]] && return 0
  return 1
}

reference_exists() {
  local ref="$1"
  local installed_ref

  [[ -e "$ROOT/$ref" || -e "$REPO_ROOT/$ref" ]] && return 0

  if [[ "$ref" == .ai-control/control/* ]]; then
    installed_ref="${ref#.ai-control/control/}"
    [[ -e "$ROOT/$installed_ref" ]] && return 0
  fi

  return 1
}

check_required_references() {
  local file="$1"
  local ref

  while IFS= read -r ref; do
    should_skip_reference "$ref" && continue
    if ! reference_exists "$ref"; then
      error "$file required reference does not exist: $ref"
    fi
  done < <(
    awk '
      /^## 必须读取/ { in_section=1; next }
      in_section && /^## / { in_section=0 }
      in_section && /^[[:space:]]*-[[:space:]]*`[^`]+`/ {
        line=$0
        sub(/^[[:space:]]*-[[:space:]]*`/, "", line)
        sub(/`.*/, "", line)
        print line
      }
    ' "$file"
  )
}

[[ -d "$AGENTS_DIR" ]] || error "Missing agents directory"

while IFS= read -r file; do
  agent="$(basename "$file" .md)"
  count=$((count + 1))

  if [[ "$agent" != agent-* ]]; then
    error "$file must use agent-*.md naming"
  fi

  first_heading="$(grep -m 1 '^# ' "$file" || true)"
  if [[ "$first_heading" != "# $agent" && "$first_heading" != *"（${agent}）" && "$first_heading" != *"(${agent})" ]]; then
    error "$file first heading must be '# $agent' or Chinese role title containing '$agent'"
  fi

  if [[ "$first_heading" != "# $agent" ]] && ! grep -q '^## 角色名称' "$file"; then
    error "$file with Chinese role title must include '## 角色名称'"
  fi

  if ! grep -q '^## 职责' "$file"; then
    error "$file missing '## 职责' section"
  fi

  if ! grep -q '^## 必须读取' "$file"; then
    warn "$file has no '## 必须读取' section"
  else
    check_required_references "$file"
  fi

  if ! grep -q '^## 停止并询问' "$file"; then
    error "$file missing '## 停止并询问' section (required by AGENT_BASE)"
  fi

  if [[ "$agent" == "agent-dev" ]]; then
    if ! grep -q '禁止把 gupo adapter 用于非 gupo 项目' "$file"; then
      error "$file must forbid gupo adapter outside gupo projects"
    fi
  fi
done < <(find "$AGENTS_DIR" -maxdepth 1 -type f -name 'agent-*.md' | sort)

if [[ "$count" -eq 0 ]]; then
  error "No agents found"
fi

if find "$AGENTS_DIR" -mindepth 2 -type f | grep -q .; then
  error "Nested files are not allowed under agents"
fi

if [[ -f "$ROOT/profiles/default/profile.toml" ]]; then
  if ! grep -q '"agents"' "$ROOT/profiles/default/profile.toml"; then
    error "profiles/default/profile.toml should install agents"
  fi
fi

# 仓库根 AGENTS.md 必须由 control/AGENTS.md 生成，禁止手改后不同步
if [[ -f "$ROOT/../AGENTS.md" && -x "$ROOT/scripts/sync-agents-md.sh" ]]; then
  if ! bash "$ROOT/scripts/sync-agents-md.sh" --check >/dev/null 2>&1; then
    error "root AGENTS.md is out of sync with control/AGENTS.md; edit control/AGENTS.md and run sync-agents-md.sh"
  fi
fi

if [[ "$fail" -eq 1 ]]; then
  printf 'Agent check failed.\n'
  exit 2
fi

printf 'Agent check passed. agents=%s\n' "$count"
