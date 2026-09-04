#!/usr/bin/env bats
# test-cases-sync.sh：按 JUnit 报告自动回填用例状态

load test_helper

make_change_with_cases() {
  CHANGE="$BATS_TEST_TMPDIR/changes/demo"
  mkdir -p "$CHANGE"
  cat > "$CHANGE/test-cases.md" <<'EOF'
# 测试用例

| 用例ID | 关联场景 | 类型 | 验证方式 | 状态 |
|--------|----------|------|----------|------|
| TC-01 | 分页查询 | 正常流 | 集成 | 已设计 |
| TC-02 | 非法参数 | 异常流 | 单测 | 已设计 |
| TC-03 | 错误态展示 | 异常流 | 手动 | 已设计 |
| TC-04 | 权限拦截 | 权限 | 集成 | 已设计 |
EOF
}

write_junit() {
  REPORT_DIR="$BATS_TEST_TMPDIR/reports"
  mkdir -p "$REPORT_DIR"
  cat > "$REPORT_DIR/TEST-demo.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="DemoTest" tests="3" failures="1">
  <testcase classname="DemoTest" name="test_TC01_分页查询"/>
  <testcase classname="DemoTest" name="tc-02 非法参数">
    <failure message="expected 400 but got 500"/>
  </testcase>
  <testcase classname="DemoTest" name="test_TC03_手动占位"/>
</testsuite>
EOF
}

setup() {
  make_change_with_cases
  write_junit
}

@test "通过与失败按报告回填" {
  run bash "$SCRIPTS_DIR/test-cases-sync.sh" "$CHANGE" "$REPORT_DIR"
  [ "$status" -eq 0 ]
  grep -q '| TC-01 | 分页查询 | 正常流 | 集成 | 通过 |' "$CHANGE/test-cases.md"
  grep -q '| TC-02 | 非法参数 | 异常流 | 单测 | 失败 |' "$CHANGE/test-cases.md"
}

@test "手动用例即使报告里有同名 ID 也不回填" {
  run bash "$SCRIPTS_DIR/test-cases-sync.sh" "$CHANGE" "$REPORT_DIR"
  [ "$status" -eq 0 ]
  grep -q '| TC-03 | 错误态展示 | 异常流 | 手动 | 已设计 |' "$CHANGE/test-cases.md"
}

@test "报告中匹配不到的用例保持已设计" {
  run bash "$SCRIPTS_DIR/test-cases-sync.sh" "$CHANGE" "$REPORT_DIR"
  [ "$status" -eq 0 ]
  grep -q '| TC-04 | 权限拦截 | 权限 | 集成 | 已设计 |' "$CHANGE/test-cases.md"
  grep -q 'SYNC_UNMATCHED=1' <<<"$output"
}

@test "回填后 --require-filled 仍拦住未覆盖用例" {
  bash "$SCRIPTS_DIR/test-cases-sync.sh" "$CHANGE" "$REPORT_DIR"
  run bash "$SCRIPTS_DIR/test-cases-check.sh" --require-filled "$CHANGE"
  [ "$status" -eq 2 ]
}

@test "无报告目录时跳过且不改文件" {
  before="$(cat "$CHANGE/test-cases.md")"
  run bash "$SCRIPTS_DIR/test-cases-sync.sh" "$CHANGE" "$BATS_TEST_TMPDIR/no-such-dir"
  [ "$status" -eq 0 ]
  [ "$(cat "$CHANGE/test-cases.md")" = "$before" ]
}

@test "TC01/TC-01/TC_01 命名变体都能匹配" {
  cat > "$REPORT_DIR/TEST-demo.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="DemoTest" tests="2">
  <testcase classname="DemoTest" name="TC_01_变体一"/>
  <testcase classname="Tc04Test" name="should_block_without_permission"/>
</testsuite>
EOF
  run bash "$SCRIPTS_DIR/test-cases-sync.sh" "$CHANGE" "$REPORT_DIR"
  grep -q '| TC-01 | 分页查询 | 正常流 | 集成 | 通过 |' "$CHANGE/test-cases.md"
  grep -q '| TC-04 | 权限拦截 | 权限 | 集成 | 通过 |' "$CHANGE/test-cases.md"
}
