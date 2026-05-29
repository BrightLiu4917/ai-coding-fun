#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEEPV4_ENV_FILE="$ROOT/.agent/deepv4.env"
REVIEW_DIR="$ROOT/.agent/reviews"
INPUT_FILE="${1:-$REVIEW_DIR/deepv4-input.md}"
OUTPUT_FILE="${2:-$REVIEW_DIR/deepv4-output.md}"

if [[ -f "$DEEPV4_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$DEEPV4_ENV_FILE"
  set +a
fi

mkdir -p "$REVIEW_DIR"

if [[ ! -f "$INPUT_FILE" ]]; then
  bash "$ROOT/scripts/prepare-deepv4-review.sh" "$INPUT_FILE" >/dev/null
fi

if [[ -z "${DEEPV4_REVIEW_COMMAND:-}" ]]; then
  printf 'DEEPV4_REVIEW_SKIPPED: DEEPV4_REVIEW_COMMAND is not configured.\n' | tee "$OUTPUT_FILE"
  exit 0
fi

printf 'DEEPV4_INPUT=%s\n' "$INPUT_FILE"
printf 'DEEPV4_OUTPUT=%s\n' "$OUTPUT_FILE"
printf 'DEEPV4_REVIEW_RUNNING: %s\n' "$DEEPV4_REVIEW_COMMAND"

# shellcheck disable=SC2086
$DEEPV4_REVIEW_COMMAND "$INPUT_FILE" | tee "$OUTPUT_FILE"

printf 'DEEPV4_OUTPUT=%s\n' "$OUTPUT_FILE"
