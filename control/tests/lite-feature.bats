#!/usr/bin/env bats
# feature --lite 小需求快速通道

load test_helper

setup() {
  PROJ="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$PROJ/.ai-control/control"
  cp -R "$REPO_ROOT/control/scripts" "$PROJ/.ai-control/control/"
  cp -R "$REPO_ROOT/control/openspec" "$PROJ/.ai-control/control/" 2>/dev/null || true
  AI="$PROJ/.ai-control/control/scripts/ai-dev.sh"
}

@test "lite 只生成三个文件，不生成 design 和 specs" {
  run bash "$AI" feature tiny-fix --lite
  [ "$status" -eq 0 ]
  CHANGE="$PROJ/openspec/changes/tiny-fix"
  [ -f "$CHANGE/proposal.md" ]
  [ -f "$CHANGE/tasks.md" ]
  [ -f "$CHANGE/test-cases.md" ]
  [ ! -f "$CHANGE/design.md" ]
  [ ! -d "$CHANGE/specs" ]
  grep -q '^变更级别: lite' "$CHANGE/proposal.md"
}

@test "lite 骨架直接通过 openspec-check" {
  bash "$AI" feature tiny-fix --lite >/dev/null
  run bash "$PROJ/.ai-control/control/scripts/openspec-check.sh" "$PROJ/openspec/changes/tiny-fix"
  [ "$status" -eq 0 ]
}

@test "lite 声明数据库影响时被 impact-check 拦截" {
  bash "$AI" feature tiny-fix --lite >/dev/null
  python3 - "$PROJ/openspec/changes/tiny-fix/proposal.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("affected_tables:\n  - none", "affected_tables:\n  - t_user")
open(p, "w", encoding="utf-8").write(s)
PY
  run bash "$PROJ/.ai-control/control/scripts/impact-check.sh" "$PROJ/openspec/changes/tiny-fix"
  [ "$status" -eq 2 ]
  grep -q 'lite' <<<"$output"
  grep -q '升级' <<<"$output"
}

@test "lite 声明 API 影响时同样被拦截" {
  bash "$AI" feature tiny-fix --lite >/dev/null
  python3 - "$PROJ/openspec/changes/tiny-fix/proposal.md" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("affected_apis:\n  - none", "affected_apis:\n  - GET /api/admin/v1/demo")
open(p, "w", encoding="utf-8").write(s)
PY
  run bash "$PROJ/.ai-control/control/scripts/impact-check.sh" "$PROJ/openspec/changes/tiny-fix"
  [ "$status" -eq 2 ]
}

@test "完整流程（不带 --lite）不受 lite 门禁影响" {
  bash "$AI" feature big-feature >/dev/null
  # 完整骨架声明表影响不应触发 lite 拦截（只会走正常的 5 字段校验）
  run bash "$PROJ/.ai-control/control/scripts/impact-check.sh" "$PROJ/openspec/changes/big-feature"
  ! grep -q 'lite 变更不允许' <<<"$output"
}
