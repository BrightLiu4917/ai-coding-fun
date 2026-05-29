#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  local relative_path
  relative_path="$(cd "$(dirname "$file")" && pwd)/$target"
  if [[ -e "$relative_path" || -e "$path" ]]; then
    checked=$((checked + 1))
  else
    error "${file#$ROOT/}: broken repo path '$target'"
  fi
}

extract_repo_paths() {
  local file="$1"
  grep -Eo '`[^`]+`' "$file" \
    | tr -d '`' \
    | grep -E '^(./)?(docs|openspec|profiles|scripts|templates|tools|examples)/|^(AGENTS|CODEX_TASK_TEMPLATE|CONTEXT|CONTEXT-MAP|README)(\.md)?$' \
    || true
}

while IFS= read -r file; do
  while IFS= read -r link; do
    check_link "$file" "$link"
  done < <(grep -Eo '\[[^]]+\]\([^)]+\)' "$file" | sed -E 's/^.*\]\(([^)]+)\)$/\1/' || true)

  while IFS= read -r path; do
    check_repo_path "$file" "$path"
  done < <(extract_repo_paths "$file")
done < <(find "$ROOT" \
  -path "$ROOT/.git" -prune -o \
  -path "$ROOT/.agent" -prune -o \
  -path "$ROOT/.idea" -prune -o \
  -path "*/.agent" -prune -o \
  -path "*/.git.bak-*" -prune -o \
  -path "*/node_modules" -prune -o \
  -path "*/.pnpm" -prune -o \
  -path "*/target" -prune -o \
  -path "*/dist" -prune -o \
  -name '*.md' -type f -print | sort)

if [[ "$fail" -eq 1 ]]; then
  printf 'Docs link check failed. checked=%s\n' "$checked"
  exit 2
fi

printf 'Docs link check passed. checked=%s\n' "$checked"
