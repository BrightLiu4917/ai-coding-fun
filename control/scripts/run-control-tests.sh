#!/usr/bin/env bash
set -euo pipefail

# 运行控制系统自身的 bats 测试（control/tests/）。
# 本地：brew install bats-core 或 npm i -g bats；也可临时用 npx --yes bats。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$ROOT/tests"

if [[ ! -d "$TESTS_DIR" ]]; then
  echo "未找到测试目录: $TESTS_DIR" >&2
  exit 1
fi

if command -v bats >/dev/null 2>&1; then
  exec bats "$TESTS_DIR"
fi

if command -v npx >/dev/null 2>&1; then
  exec npx --yes bats "$TESTS_DIR"
fi

echo "未找到 bats。安装方式：brew install bats-core 或 npm install -g bats" >&2
exit 1
