#!/usr/bin/env bash
set -euo pipefail

CHANGE_DIR="${1:-}"

if [[ -z "$CHANGE_DIR" || ! -d "$CHANGE_DIR" ]]; then
  echo "Usage: $0 openspec/changes/<change-id>"
  exit 1
fi

fail=0

require_file() {
  local file="$CHANGE_DIR/$1"
  if [[ ! -f "$file" ]]; then
    echo "[FAIL] Missing $file"
    fail=1
  fi
}

require_file "proposal.md"
require_file "tasks.md"

if [[ -x "$(dirname "$0")/impact-check.sh" ]]; then
  "$(dirname "$0")/impact-check.sh" "$CHANGE_DIR" || fail=1
fi

if [[ -x "$(dirname "$0")/route-compliance-check.sh" ]]; then
  "$(dirname "$0")/route-compliance-check.sh" "$CHANGE_DIR" || fail=1
fi

if [[ -x "$(dirname "$0")/test-cases-check.sh" ]]; then
  "$(dirname "$0")/test-cases-check.sh" "$CHANGE_DIR" || fail=1
fi

# 语言规范检查已从默认链摘除（误报多、价值低）；需要时手动运行 openspec-language-check.sh
if [[ ! -d "$CHANGE_DIR/specs" ]]; then
  echo "[WARN] Missing specs delta directory: $CHANGE_DIR/specs"
fi

if [[ "$fail" -eq 1 ]]; then
  echo "OpenSpec check failed."
  exit 2
fi

echo "OpenSpec check passed."
