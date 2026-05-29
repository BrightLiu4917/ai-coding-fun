#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/.agent/logs"
LOG_FILE="$LOG_DIR/test.log"
AI_CONTROL_ENV_FILE="$ROOT/.ai-control/project.env"
PROJECT_ENV_FILE="$ROOT/.agent/project.env"
SELF_SCRIPT="$ROOT/scripts/run-tests.sh"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

if [[ -f "$AI_CONTROL_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$AI_CONTROL_ENV_FILE"
  set +a
fi

if [[ -f "$PROJECT_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$PROJECT_ENV_FILE"
  set +a
fi

is_self_test_command() {
  local command="$1"

  [[ "$command" == *"$SELF_SCRIPT"* ]] && return 0

  printf '%s\n' "$command" | grep -Eq '(^|[[:space:];|&])((bash|sh)[[:space:]]+)?(\./)?scripts/run-tests\.sh([[:space:];|&]|$)'
}

if [[ -n "${PROJECT_TEST_COMMAND:-}" ]] && is_self_test_command "$PROJECT_TEST_COMMAND"; then
  printf 'TEST_FAILED: PROJECT_TEST_COMMAND points to scripts/run-tests.sh itself. Set a real project test command in .ai-control/project.env or .agent/project.env.\n' | tee -a "$LOG_FILE"
  exit 2
fi

run_step() {
  local name="$1"
  shift

  printf '==> %s\n' "$name" | tee -a "$LOG_FILE"
  "$@" 2>&1 | tee -a "$LOG_FILE"
}

run_shell_step() {
  local name="$1"
  local command="$2"

  printf '==> %s\n' "$name" | tee -a "$LOG_FILE"
  bash -lc "$command" 2>&1 | tee -a "$LOG_FILE"
}

cd "$ROOT"

if [[ -n "${PROJECT_TEST_COMMAND:-}" ]]; then
  run_shell_step "PROJECT_TEST_COMMAND" "$PROJECT_TEST_COMMAND"
elif [[ -f "pom.xml" ]]; then
  if command -v mvn >/dev/null 2>&1; then
    run_step "Maven test" mvn test
  else
    printf 'TEST_FAILED: mvn not found. Set PROJECT_TEST_COMMAND or install Maven.\n' | tee -a "$LOG_FILE"
    exit 127
  fi
elif [[ -f "package.json" ]]; then
  if command -v npm >/dev/null 2>&1; then
    if [[ -f "package-lock.json" ]]; then
      run_step "npm ci" npm ci
    else
      run_step "npm install" npm install
    fi
    if npm run | grep -Eq '^[[:space:]]+test'; then
      run_step "npm test" npm test
    fi
    if npm run | grep -Eq '^[[:space:]]+build'; then
      run_step "npm build" npm run build
    fi
  else
    printf 'TEST_FAILED: npm not found. Set PROJECT_TEST_COMMAND or install Node.js.\n' | tee -a "$LOG_FILE"
    exit 127
  fi
elif [[ -f "go.mod" ]]; then
  if command -v go >/dev/null 2>&1; then
    run_step "go test" go test ./...
  else
    printf 'TEST_FAILED: go not found. Set PROJECT_TEST_COMMAND or install Go.\n' | tee -a "$LOG_FILE"
    exit 127
  fi
elif [[ -f "composer.json" ]]; then
  if [[ -x "vendor/bin/phpunit" ]]; then
    run_step "phpunit" vendor/bin/phpunit
  else
    printf 'TEST_FAILED: vendor/bin/phpunit not found. Set PROJECT_TEST_COMMAND or install dependencies.\n' | tee -a "$LOG_FILE"
    exit 127
  fi
else
  printf 'TEST_FAILED: no supported project test entry found. Set PROJECT_TEST_COMMAND.\n' | tee -a "$LOG_FILE"
  exit 2
fi

printf 'TEST_PASSED\n' | tee -a "$LOG_FILE"
