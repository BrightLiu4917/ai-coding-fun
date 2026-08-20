#!/usr/bin/env bats
# 独立二审调度：未配置跳过、分级触发、VERDICT 门禁、skip-review 留痕

load test_helper

setup() {
  PROJ="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$PROJ/.ai-control/control" "$PROJ/.agent"
  cp -R "$REPO_ROOT/control/scripts" "$PROJ/.ai-control/control/"
  cp -R "$REPO_ROOT/control/templates" "$PROJ/.ai-control/control/"
  git -C "$PROJ" init -q
  SCRIPTS="$PROJ/.ai-control/control/scripts"
  INPUT="$PROJ/.agent/reviews/review-input.md"
  mkdir -p "$PROJ/.agent/reviews"
  echo "# 审查输入" > "$INPUT"
}

# 生成一个输出固定内容的假审查命令
fake_reviewer() {
  local out="$1"
  cat > "$PROJ/fake-reviewer.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "审查意见..." "$out"
EOF
  chmod +x "$PROJ/fake-reviewer.sh"
}

write_env() {
  cat > "$PROJ/.agent/review.env" <<EOF
REVIEW_COMMAND='bash $PROJ/fake-reviewer.sh'
${1:-}
EOF
}

@test "未配置时直接跳过且 exit 0" {
  run bash "$SCRIPTS/run-review.sh" "$INPUT"
  [ "$status" -eq 0 ]
  grep -q 'REVIEW_SKIPPED' <<<"$output"
  grep -q '未配置' "$PROJ/.agent/reviews/review-skip.log"
}

@test "VERDICT: PASS 正常放行" {
  fake_reviewer "VERDICT: PASS"
  write_env
  run bash "$SCRIPTS/run-review.sh" "$INPUT"
  [ "$status" -eq 0 ]
  grep -q 'REVIEW_VERDICT=PASS' <<<"$output"
}

@test "VERDICT: BLOCK 拦截并 exit 2" {
  fake_reviewer "VERDICT: BLOCK"
  write_env
  run bash "$SCRIPTS/run-review.sh" "$INPUT"
  [ "$status" -eq 2 ]
  grep -q 'REVIEW_VERDICT=BLOCK' <<<"$output"
}

@test "无 VERDICT 行按旧格式放行并告警" {
  fake_reviewer "没有结论行的旧格式输出"
  write_env
  run bash "$SCRIPTS/run-review.sh" "$INPUT"
  [ "$status" -eq 0 ]
  grep -q 'REVIEW_VERDICT_MISSING' <<<"$output"
}

@test "REVIEW_MODE=never 跳过并留痕" {
  fake_reviewer "VERDICT: PASS"
  write_env "REVIEW_MODE='never'"
  run bash "$SCRIPTS/run-review.sh" "$INPUT"
  [ "$status" -eq 0 ]
  grep -q 'REVIEW_SKIPPED' <<<"$output"
}

@test "auto 模式下 lite 变更跳过二审" {
  fake_reviewer "VERDICT: PASS"
  write_env "REVIEW_MODE='auto'"
  mkdir -p "$PROJ/openspec/changes/tiny"
  printf '# 变更提案\n\n变更级别: lite\n' > "$PROJ/openspec/changes/tiny/proposal.md"
  OPENSPEC_CHANGE_ID=tiny run bash "$SCRIPTS/run-review.sh" "$INPUT"
  [ "$status" -eq 0 ]
  grep -q 'lite' <<<"$output"
  grep -q 'REVIEW_SKIPPED' <<<"$output"
}

@test "auto 模式下完整变更照常执行" {
  fake_reviewer "VERDICT: PASS"
  write_env "REVIEW_MODE='auto'"
  mkdir -p "$PROJ/openspec/changes/big"
  printf '# 变更提案\n' > "$PROJ/openspec/changes/big/proposal.md"
  OPENSPEC_CHANGE_ID=big run bash "$SCRIPTS/run-review.sh" "$INPUT"
  [ "$status" -eq 0 ]
  grep -q 'REVIEW_VERDICT=PASS' <<<"$output"
}

@test "旧 deepv4.env 与 DEEPV4_REVIEW_COMMAND 兼容可用" {
  fake_reviewer "VERDICT: PASS"
  cat > "$PROJ/.agent/deepv4.env" <<EOF
DEEPV4_REVIEW_COMMAND='bash $PROJ/fake-reviewer.sh'
EOF
  run bash "$SCRIPTS/run-review.sh" "$INPUT"
  [ "$status" -eq 0 ]
  grep -q 'REVIEW_VERDICT=PASS' <<<"$output"
}

@test "ai ship --skip-review 需要原因且留痕" {
  cp "$REPO_ROOT/control/templates/ai-launcher.sh" "$PROJ/ai"
  chmod +x "$PROJ/ai"
  mkdir -p "$PROJ/openspec/changes/demo"
  # 用例门禁先于 skip-review 生效（跳过二审不等于跳过用例回填），给一份已回填的用例
  cat > "$PROJ/openspec/changes/demo/test-cases.md" <<'EOF'
| 用例ID | 类型 | 状态 |
|--------|------|------|
| TC-01 | 正常流 | 通过 |
EOF
  # 无原因 → 报错
  run "$PROJ/ai" ship demo --skip-review
  [ "$status" -eq 1 ]
  # 有原因 → 跳过并留痕
  run "$PROJ/ai" ship demo --skip-review "二审服务欠费，走人工审查"
  [ "$status" -eq 0 ]
  grep -q 'SKIPPED_BY_USER: 二审服务欠费' "$PROJ/.agent/reviews/review-skip.log"
}
