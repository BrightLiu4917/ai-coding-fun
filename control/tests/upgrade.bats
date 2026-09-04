#!/usr/bin/env bats
# upgrade-control.sh：框架升级，不碰用户数据

load test_helper

setup() {
  # 模拟"旧版源仓库"和"已安装项目"
  SRC="$BATS_TEST_TMPDIR/source-repo"
  PROJ="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$SRC/control/scripts" "$SRC/control/templates"
  cp -R "$REPO_ROOT/control/scripts/upgrade-control.sh" "$SRC/control/scripts/"
  cp "$REPO_ROOT/control/AGENTS.md" "$SRC/control/AGENTS.md"
  cp "$REPO_ROOT/control/templates/ai-launcher.sh" "$SRC/control/templates/"
  echo "2.0.0" > "$SRC/control/VERSION"
  echo "新版规则" > "$SRC/control/NEW_RULE.md"

  mkdir -p "$PROJ/.ai-control/control/scripts" "$PROJ/openspec/changes/keep-me" "$PROJ/.agent"
  cp "$REPO_ROOT/control/scripts/upgrade-control.sh" "$PROJ/.ai-control/control/scripts/"
  echo "1.0.0" > "$PROJ/.ai-control/VERSION"
  echo "旧契约" > "$PROJ/AGENTS.md"
  echo "PROJECT_NAME='demo'" > "$PROJ/.ai-control/project.env"
  echo "用户的需求记录" > "$PROJ/openspec/changes/keep-me/proposal.md"
  echo "用户的上下文" > "$PROJ/CONTEXT.md"
}

@test "升级替换框架文件并写入新版本号" {
  run bash "$PROJ/.ai-control/control/scripts/upgrade-control.sh" --source "$SRC" "$PROJ"
  [ "$status" -eq 0 ]
  grep -q 'UPGRADE_OK' <<<"$output"
  [ "$(cat "$PROJ/.ai-control/VERSION")" = "2.0.0" ]
  [ -f "$PROJ/.ai-control/control/NEW_RULE.md" ]
}

@test "用户数据完全不被触碰" {
  bash "$PROJ/.ai-control/control/scripts/upgrade-control.sh" --source "$SRC" "$PROJ" >/dev/null
  [ "$(cat "$PROJ/openspec/changes/keep-me/proposal.md")" = "用户的需求记录" ]
  [ "$(cat "$PROJ/CONTEXT.md")" = "用户的上下文" ]
  grep -q "PROJECT_NAME='demo'" "$PROJ/.ai-control/project.env"
}

@test "升级前自动备份且可回退" {
  bash "$PROJ/.ai-control/control/scripts/upgrade-control.sh" --source "$SRC" "$PROJ" >/dev/null
  backup="$(find "$PROJ/.agent/install-backup" -maxdepth 1 -name 'upgrade-*' | head -1)"
  [ -n "$backup" ]
  [ "$(cat "$backup/AGENTS.md")" = "旧契约" ]
  [ -d "$backup/control" ]
}

@test "版本相同时不动任何文件" {
  echo "2.0.0" > "$PROJ/.ai-control/VERSION"
  run bash "$PROJ/.ai-control/control/scripts/upgrade-control.sh" --source "$SRC" "$PROJ"
  [ "$status" -eq 0 ]
  grep -q '无需升级' <<<"$output"
  [ "$(cat "$PROJ/AGENTS.md")" = "旧契约" ]
}

@test "找不到升级源时明确报错" {
  run bash "$PROJ/.ai-control/control/scripts/upgrade-control.sh" "$PROJ"
  [ "$status" -eq 1 ]
  grep -q '升级源' <<<"$output"
}
