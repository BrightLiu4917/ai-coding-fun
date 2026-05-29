#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${1:-$ROOT/.agent/logs/test.log}"
TAIL_LINES="${TAIL_LINES:-160}"

if [[ ! -f "$LOG_FILE" ]]; then
  printf 'LOG_NOT_FOUND: %s\n' "$LOG_FILE" >&2
  exit 2
fi

printf 'LOG_FILE=%s\n' "$LOG_FILE"

if grep -Eqi 'TEST_PASSED|BUILD SUCCESS|Tests run: .*Failures: 0, Errors: 0|PASS|passed' "$LOG_FILE"; then
  printf 'STATUS_HINT=passed_or_partially_passed\n'
fi

if grep -Eqi 'TEST_FAILED|BUILD FAILURE|Compilation failure|FAILED|FAIL|ERROR|Exception|Caused by|AssertionError' "$LOG_FILE"; then
  printf 'STATUS_HINT=failed_or_needs_attention\n'
  printf '\nKEY_LINES:\n'
  grep -Ein 'TEST_FAILED|BUILD FAILURE|Compilation failure|FAILED|FAIL|ERROR|Exception|Caused by|AssertionError|Tests run:' "$LOG_FILE" | tail -n 80 || true
fi

printf '\nTAIL_%s_LINES:\n' "$TAIL_LINES"
tail -n "$TAIL_LINES" "$LOG_FILE"
