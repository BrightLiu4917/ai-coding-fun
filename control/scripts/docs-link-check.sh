#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  REPO_ROOT="$(cd "$ROOT/.." && pwd)"
fi
fail=0
checked=0

error() {
  printf '[FAIL] %s\n' "$*"
  fail=1
}

should_skip_target() {
  local target="$1"
  [[ "$target" == http://* || "$target" == https://* || "$target" == mailto:* || "$target" == "#"* ]] && return 0
  [[ "$target" == /* ]] && return 0
  [[ -z "$target" ]] && return 0
  [[ "$target" == *"<"* || "$target" == *">"* ]] && return 0
  [[ "$target" == *"*"* ]] && return 0
  [[ "$target" == *"..."* ]] && return 0
  [[ "$target" == --* ]] && return 0
  [[ "$target" == .agent/* ]] && return 0
  [[ "$target" == tools/codegen/java-springboot-crud-adapters/gupo* ]] && return 0
  return 1
}

check_link() {
  local file="$1"
  local target="$2"
  should_skip_target "$target" && return

  target="${target%%#*}"
  should_skip_target "$target" && return

  local path
  path="$(cd "$(dirname "$file")" && pwd)/$target"
  if [[ ! -e "$path" ]]; then
    error "${file#$ROOT/}: broken link '$target'"
  fi
  checked=$((checked + 1))
}

check_repo_path() {
  local file="$1"
  local target="$2"
  should_skip_target "$target" && return

  target="${target%%#*}"
  should_skip_target "$target" && return

  local path="$ROOT/${target#./}"
  local repo_path="$REPO_ROOT/${target#./}"
  local source_path=""
  if [[ "$target" == .ai-control/control/* ]]; then
    source_path="$ROOT/${target#.ai-control/control/}"
  fi
  local relative_path
  relative_path="$(cd "$(dirname "$file")" && pwd)/$target"
  if [[ -e "$relative_path" || -e "$path" || -e "$repo_path" || ( -n "$source_path" && -e "$source_path" ) ]]; then
    checked=$((checked + 1))
  else
    error "${file#$ROOT/}: broken repo path '$target'"
  fi
}

extract_repo_paths() {
  local file="$1"
  grep -Eo '`[^`]+`' "$file" \
    | tr -d '`' \
    | grep -E '^(./)?(control/|\.ai-control/control/)?(docs|openspec|profiles|scripts|templates|tools|examples|agents)/|^(AGENTS|CODEX_TASK_TEMPLATE|CONTEXT|CONTEXT-MAP|README)(\.md)?$|^control/(CODEX_TASK_TEMPLATE|CONTEXT|CONTEXT-MAP)(\.md)?$' \
    || true
}

while IFS= read -r file; do
  while IFS= read -r link; do
    check_link "$file" "$link"
  done < <(grep -Eo '\[[^]]+\]\([^)]+\)' "$file" | sed -E 's/^.*\]\(([^)]+)\)$/\1/' || true)

  while IFS= read -r path; do
    check_repo_path "$file" "$path"
  done < <(extract_repo_paths "$file")
done < <(
  {
    [[ -f "$REPO_ROOT/AGENTS.md" ]] && printf '%s\n' "$REPO_ROOT/AGENTS.md"
    [[ -f "$REPO_ROOT/README.md" ]] && printf '%s\n' "$REPO_ROOT/README.md"
    find "$ROOT" \
  -path "$ROOT/.git" -prune -o \
  -path "$ROOT/.agent" -prune -o \
  -path "$ROOT/openspec/changes" -prune -o \
  -path "$ROOT/.idea" -prune -o \
  -path "*/.agent" -prune -o \
  -path "*/.git.bak-*" -prune -o \
  -path "*/node_modules" -prune -o \
  -path "*/.pnpm" -prune -o \
  -path "*/target" -prune -o \
  -path "*/dist" -prune -o \
  -name '*.md' -type f -print
  } | sort -u
)

if [[ "$fail" -eq 1 ]]; then
  printf 'Docs link check failed. checked=%s\n' "$checked"
  exit 2
fi

printf 'Docs link check passed. checked=%s\n' "$checked"
