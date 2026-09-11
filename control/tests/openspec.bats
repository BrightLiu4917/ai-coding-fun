#!/usr/bin/env bats
# OpenSpec 检查链：openspec-check / impact-check / route-compliance-check / test-cases-check / openspec-conflict-check

load test_helper

# 生成一个完整合规的 change 目录
make_change() {
  CHANGE="$BATS_TEST_TMPDIR/changes/demo-change"
  mkdir -p "$CHANGE/specs/demo"

  cat > "$CHANGE/proposal.md" <<'EOF'
# 变更提案：示例功能

## 背景
补充示例功能。

## 影响范围

affected_files:
  - src/main/java/Demo.java
affected_tables:
  - none
affected_apis:
  - GET /api/admin/v1/demo/page
affected_pages:
  - none
affected_agents:
  - agent-java
EOF

  cat > "$CHANGE/tasks.md" <<'EOF'
# 任务清单

- [ ] 确认 API 契约（agent-api）并完成接口实现。
- [ ] 按 test-cases.md 执行验证并审查结果。
EOF

  cat > "$CHANGE/test-cases.md" <<'EOF'
# 测试用例

| 用例ID | 关联场景 | 类型 | 前置条件 | 步骤 | 预期结果 | 验证方式 | 状态 |
|--------|----------|------|----------|------|----------|----------|------|
| TC-01 | 分页查询 | 正常流 | 已有数据 | 调用分页接口 | 返回分页数据 | 集成 | 通过 |
| TC-02 | 非法参数 | 异常流 | 已登录 | 传入非法分页参数 | 返回参数错误 | 单测 | 通过 |
EOF

  cat > "$CHANGE/specs/demo/spec.md" <<'EOF'
# 示例能力规格

## 场景

#### 场景：分页查询
- 已有数据时按时间倒序分页返回。
EOF
}

setup() {
  make_change
}

@test "完整 change 通过 openspec-check 聚合检查" {
  run bash "$SCRIPTS_DIR/openspec-check.sh" "$CHANGE"
  [ "$status" -eq 0 ]
}

@test "缺少 test-cases.md 时 openspec-check 失败" {
  rm "$CHANGE/test-cases.md"
  run bash "$SCRIPTS_DIR/openspec-check.sh" "$CHANGE"
  [ "$status" -eq 2 ]
  grep -q 'test-cases' <<<"$output"
}

@test "test-cases.md 无用例行时失败" {
  cat > "$CHANGE/test-cases.md" <<'EOF'
# 测试用例
暂无。
EOF
  run bash "$SCRIPTS_DIR/test-cases-check.sh" "$CHANGE"
  [ "$status" -eq 2 ]
}

@test "affected_apis 非 none 但缺异常流用例时失败" {
  cat > "$CHANGE/test-cases.md" <<'EOF'
| 用例ID | 类型 | 状态 |
|--------|------|------|
| TC-01 | 正常流 | 通过 |
EOF
  run bash "$SCRIPTS_DIR/test-cases-check.sh" "$CHANGE"
  [ "$status" -eq 2 ]
  grep -q '异常流' <<<"$output"
}

@test "affected_pages 非 none 但缺权限或空态用例时失败" {
  # 把 pages 改为非 none
  python3 - "$CHANGE/proposal.md" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("affected_pages:\n  - none", "affected_pages:\n  - 示例页面")
open(p, "w", encoding="utf-8").write(s)
PY
  run bash "$SCRIPTS_DIR/test-cases-check.sh" "$CHANGE"
  [ "$status" -eq 2 ]
  grep -q '权限' <<<"$output"
}

@test "--evidence 按 JUnit 报告核对：缺失/失败拦截，全绿通过" {
  cat > "$CHANGE/test-cases.md" <<'EOF'
| 用例ID | 类型 | 验证方式 |
|--------|------|----------|
| TC-01 | 正常流 | 集成 |
| TC-02 | 异常流 | 单测 |
| TC-03 | 边界 | 手动 |
EOF
  REPORTS="$BATS_TEST_TMPDIR/reports"
  mkdir -p "$REPORTS"
  # 只有 TC-01 有通过记录 → TC-02 缺证据被拦（TC-03 手动不核对）
  cat > "$REPORTS/TEST-a.xml" <<'EOF'
<?xml version="1.0"?>
<testsuite tests="1"><testcase classname="T" name="test_TC01_ok"/></testsuite>
EOF
  run bash "$SCRIPTS_DIR/test-cases-check.sh" --evidence "$CHANGE" "$REPORTS"
  [ "$status" -eq 2 ]
  grep -q 'MISSING_CASE: TC-02' <<<"$output"

  # 补上 TC-02 但让它失败 → 失败拦截
  cat > "$REPORTS/TEST-a.xml" <<'EOF'
<?xml version="1.0"?>
<testsuite tests="2">
  <testcase classname="T" name="test_TC01_ok"/>
  <testcase classname="T" name="test_TC02_bad"><failure message="boom"/></testcase>
</testsuite>
EOF
  run bash "$SCRIPTS_DIR/test-cases-check.sh" --evidence "$CHANGE" "$REPORTS"
  [ "$status" -eq 2 ]
  grep -q 'FAILED_TEST' <<<"$output"

  # 全绿 → 通过；手动用例 TC-03 无需报告
  cat > "$REPORTS/TEST-a.xml" <<'EOF'
<?xml version="1.0"?>
<testsuite tests="2">
  <testcase classname="T" name="test_TC01_ok"/>
  <testcase classname="T" name="test_TC02_ok"/>
</testsuite>
EOF
  run bash "$SCRIPTS_DIR/test-cases-check.sh" --evidence "$CHANGE" "$REPORTS"
  [ "$status" -eq 0 ]
}

@test "--evidence 无报告目录时明确拦截" {
  run bash "$SCRIPTS_DIR/test-cases-check.sh" --evidence "$CHANGE" "$BATS_TEST_TMPDIR/no-such"
  [ "$status" -eq 2 ]
  grep -q 'JUnit' <<<"$output"
}

@test "impact-check 检出缺失的影响范围字段" {
  python3 - "$CHANGE/proposal.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("affected_tables:\n  - none\n", "")
open(p, "w", encoding="utf-8").write(s)
PY
  run bash "$SCRIPTS_DIR/impact-check.sh" "$CHANGE"
  [ "$status" -eq 2 ]
  grep -q 'affected_tables' <<<"$output"
}

@test "route-compliance：声明了 affected_tables 但任务清单无 DBA 项时失败" {
  python3 - "$CHANGE/proposal.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("affected_tables:\n  - none", "affected_tables:\n  - t_demo")
open(p, "w", encoding="utf-8").write(s)
PY
  run bash "$SCRIPTS_DIR/route-compliance-check.sh" "$CHANGE"
  [ "$status" -eq 2 ]
  grep -qi 'affected_tables' <<<"$output"
}

@test "conflict-check 检出两个 change 触碰同一张表" {
  CHANGES_ROOT="$BATS_TEST_TMPDIR/multi/changes"
  for name in change-a change-b; do
    mkdir -p "$CHANGES_ROOT/$name"
    cat > "$CHANGES_ROOT/$name/proposal.md" <<'EOF'
# 变更提案

## 影响范围

affected_files:
  - none
affected_tables:
  - t_shared
affected_apis:
  - none
affected_pages:
  - none
affected_agents:
  - agent-dba
EOF
  done
  run bash "$SCRIPTS_DIR/openspec-conflict-check.sh" "$CHANGES_ROOT"
  grep -q 't_shared' <<<"$output"
}
