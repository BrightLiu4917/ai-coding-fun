#!/usr/bin/env bats
# spec-drift-check.sh：规格声明与代码实现的反向比对

load test_helper

setup() {
  PROJ="$BATS_TEST_TMPDIR/proj"
  CHANGE="$PROJ/openspec/changes/demo"
  mkdir -p "$CHANGE" "$PROJ/src" "$PROJ/migrations"
  cat > "$CHANGE/proposal.md" <<'EOF'
# 变更提案

## 影响范围

affected_tables:
  - t_order
  - t_missing_table
affected_apis:
  - GET /api/admin/v1/order/page
EOF
  cat > "$CHANGE/design.md" <<'EOF'
接口：GET /api/admin/v1/order/page
另一个接口：POST /api/admin/v1/order/ghost-endpoint
EOF
  # 代码中只实现了 order/page 和 t_order
  echo '@GetMapping("/api/admin/v1/order/page")' > "$PROJ/src/OrderController.java"
  echo 'CREATE TABLE t_order (...);' > "$PROJ/migrations/001.sql"
}

@test "检出规格声明但代码缺失的 API 和表" {
  run bash "$SCRIPTS_DIR/spec-drift-check.sh" "$CHANGE" "$PROJ"
  [ "$status" -eq 0 ]
  grep -q 'ghost-endpoint' <<<"$output"
  grep -q 't_missing_table' <<<"$output"
  ! grep -q 'DRIFT.*order/page' <<<"$output"
}

@test "--strict 时漂移导致非零退出" {
  run bash "$SCRIPTS_DIR/spec-drift-check.sh" --strict "$CHANGE" "$PROJ"
  [ "$status" -eq 2 ]
}

@test "全部一致时通过" {
  echo 'POST /api/admin/v1/order/ghost-endpoint impl' >> "$PROJ/src/OrderController.java"
  echo 'CREATE TABLE t_missing_table (...);' >> "$PROJ/migrations/001.sql"
  run bash "$SCRIPTS_DIR/spec-drift-check.sh" --strict "$CHANGE" "$PROJ"
  [ "$status" -eq 0 ]
  grep -q 'passed' <<<"$output"
}

@test "未声明 API 和表时跳过" {
  cat > "$CHANGE/proposal.md" <<'EOF'
## 影响范围
affected_tables:
  - none
EOF
  rm "$CHANGE/design.md"
  run bash "$SCRIPTS_DIR/spec-drift-check.sh" "$CHANGE" "$PROJ"
  [ "$status" -eq 0 ]
  grep -q 'skipped' <<<"$output"
}
