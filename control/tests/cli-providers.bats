#!/usr/bin/env bats
# claude-cli / codex-cli provider：用 stub 假 CLI 验证接线

load test_helper

setup() {
  INPUT="$BATS_TEST_TMPDIR/review-input.md"
  printf '# 审查材料\n\n## 输出格式\n1. 阻塞问题\n' > "$INPUT"

  # 假 CLI 放进 PATH
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_BIN"
  cat > "$STUB_BIN/claude" <<'EOF'
#!/usr/bin/env bash
# 记录参数，回显 stdin 前一行，输出固定审查结论
echo "ARGS: $*" >&2
head -1 >/dev/null
echo "审查意见：无阻塞问题"
echo "VERDICT: PASS"
EOF
  cat > "$STUB_BIN/codex" <<'EOF'
#!/usr/bin/env bash
echo "ARGS: $*" >&2
echo "审查意见：发现一个风险"
echo "VERDICT: PASS_WITH_RISKS"
EOF
  chmod +x "$STUB_BIN/claude" "$STUB_BIN/codex"
  export PATH="$STUB_BIN:$PATH"
}

@test "claude-cli provider 输出含 VERDICT" {
  run bash "$SCRIPTS_DIR/providers/claude-cli.sh" "$INPUT"
  [ "$status" -eq 0 ]
  grep -q 'VERDICT: PASS' <<<"$output"
}

@test "claude-cli 透传 REVIEW_CLI_MODEL" {
  REVIEW_CLI_MODEL="opus" run bash "$SCRIPTS_DIR/providers/claude-cli.sh" "$INPUT"
  grep -q -- '--model opus' <<<"$output"
}

@test "codex-cli provider 提示词里带输入文件绝对路径" {
  run bash "$SCRIPTS_DIR/providers/codex-cli.sh" "$INPUT"
  [ "$status" -eq 0 ]
  grep -q 'VERDICT: PASS_WITH_RISKS' <<<"$output"
  grep -q "review-input.md" <<<"$output"
}

@test "CLI 缺失时明确报错" {
  PATH="/usr/bin:/bin" run bash "$SCRIPTS_DIR/providers/claude-cli.sh" "$INPUT"
  [ "$status" -eq 127 ]
  grep -q 'claude CLI 不可用' <<<"$output"
}

@test "run-review 走 claude-cli provider 全链路" {
  PROJ="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$PROJ/.ai-control/control/scripts/providers" "$PROJ/.agent/reviews"
  cp "$SCRIPTS_DIR/run-review.sh" "$PROJ/.ai-control/control/scripts/"
  cp "$SCRIPTS_DIR/prepare-review.sh" "$PROJ/.ai-control/control/scripts/" 2>/dev/null || true
  cp "$SCRIPTS_DIR/providers/claude-cli.sh" "$PROJ/.ai-control/control/scripts/providers/"
  cp "$INPUT" "$PROJ/.agent/reviews/review-input.md"
  printf "REVIEW_PROVIDER='claude-cli'\n" > "$PROJ/.agent/review.env"
  run bash "$PROJ/.ai-control/control/scripts/run-review.sh"
  [ "$status" -eq 0 ]
  grep -q 'VERDICT: PASS' "$PROJ/.agent/reviews/review-output.md"
}
