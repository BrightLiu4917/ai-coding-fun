#!/usr/bin/env bats
# 回归：AGENTS.md 单一源生成与同步校验

load test_helper

@test "生成幂等：连续两次生成结果一致" {
  before="$(shasum "$REPO_ROOT/AGENTS.md")"
  bash "$SCRIPTS_DIR/sync-agents-md.sh" >/dev/null
  bash "$SCRIPTS_DIR/sync-agents-md.sh" >/dev/null
  after="$(shasum "$REPO_ROOT/AGENTS.md")"
  [ "$before" = "$after" ]
}

@test "--check 在同步状态下通过" {
  run bash "$SCRIPTS_DIR/sync-agents-md.sh" --check
  [ "$status" -eq 0 ]
}

@test "--check 检出根文件漂移" {
  cp "$REPO_ROOT/AGENTS.md" "$BATS_TEST_TMPDIR/AGENTS.md.bak"
  echo "drift" >> "$REPO_ROOT/AGENTS.md"
  run bash "$SCRIPTS_DIR/sync-agents-md.sh" --check
  cp "$BATS_TEST_TMPDIR/AGENTS.md.bak" "$REPO_ROOT/AGENTS.md"
  [ "$status" -ne 0 ]
}
