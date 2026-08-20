#!/usr/bin/env bats
# ./ai 统一命令入口

load test_helper

setup() {
  PROJ="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$PROJ/.ai-control/control"
  cp -R "$REPO_ROOT/control/scripts" "$PROJ/.ai-control/control/"
  cp -R "$REPO_ROOT/control/templates" "$PROJ/.ai-control/control/"
  cp "$REPO_ROOT/control/templates/ai-launcher.sh" "$PROJ/ai"
  chmod +x "$PROJ/ai"
}

@test "ai help 输出用法" {
  run "$PROJ/ai" help
  [ "$status" -eq 0 ]
  grep -q 'ai new' <<<"$output"
}

@test "ai new --lite 转发到 feature 并生成 lite 骨架" {
  run "$PROJ/ai" new tiny-fix --lite
  [ "$status" -eq 0 ]
  [ -f "$PROJ/openspec/changes/tiny-fix/proposal.md" ]
  grep -q '^变更级别: lite' "$PROJ/openspec/changes/tiny-fix/proposal.md"
}

@test "ai check 转发到 ready" {
  "$PROJ/ai" new tiny-fix --lite >/dev/null
  run "$PROJ/ai" check tiny-fix
  # lite 骨架有待确认项，ready 应给出提示而非崩溃（exit 0 或 2 都是正常业务结果）
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
  grep -Eq '待确认|READY' <<<"$output"
}

@test "未知命令报错并提示 help" {
  run "$PROJ/ai" foobar
  [ "$status" -eq 1 ]
  grep -q '未知命令' <<<"$output"
}

@test "install-cli 安装全局寻路壳且能找到项目" {
  export AI_CLI_BIN_DIR="$BATS_TEST_TMPDIR/bin"
  run "$PROJ/ai" install-cli
  [ "$status" -eq 0 ]
  [ -x "$AI_CLI_BIN_DIR/ai" ]
  # 在项目子目录里执行全局壳，应转发到项目的 ./ai
  mkdir -p "$PROJ/src/deep"
  cd "$PROJ/src/deep"
  run "$AI_CLI_BIN_DIR/ai" help
  [ "$status" -eq 0 ]
  grep -q 'ai new' <<<"$output"
}

@test "项目外执行全局壳给出明确报错" {
  export AI_CLI_BIN_DIR="$BATS_TEST_TMPDIR/bin"
  "$PROJ/ai" install-cli >/dev/null
  cd "$BATS_TEST_TMPDIR"
  run "$AI_CLI_BIN_DIR/ai" help
  [ "$status" -eq 1 ]
  grep -q '不在任何控制系统项目内' <<<"$output"
}
