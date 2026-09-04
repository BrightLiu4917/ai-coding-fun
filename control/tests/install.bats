#!/usr/bin/env bats
# 回归：安装链路不得静默覆盖用户文件

load test_helper

setup() {
  TARGET="$(mktemp -d)/target"
  mkdir -p "$TARGET"
  git -C "$TARGET" init -q 2>/dev/null || true
}

teardown() {
  rm -rf "$(dirname "$TARGET")"
}

@test "install --dry-run 不写入任何文件" {
  run bash "$SCRIPTS_DIR/install-to-project.sh" --dry-run --profile default "$TARGET"
  [ "$status" -eq 0 ]
  [ ! -d "$TARGET/.ai-control" ]
  [ ! -f "$TARGET/AGENTS.md" ]
}

@test "目标已有 AGENTS.md 时默认安装中止且不拷贝" {
  echo "user content" > "$TARGET/AGENTS.md"
  run bash "$SCRIPTS_DIR/install-to-project.sh" --profile default "$TARGET"
  [ "$status" -ne 0 ]
  [ "$(cat "$TARGET/AGENTS.md")" = "user content" ]
  [ ! -d "$TARGET/.ai-control" ]
}

@test "install --backup 覆盖前备份原文件" {
  echo "user content" > "$TARGET/AGENTS.md"
  run bash "$SCRIPTS_DIR/install-to-project.sh" --backup --profile default "$TARGET"
  [ "$status" -eq 0 ]
  backup_file="$(find "$TARGET/.agent/install-backup" -name 'AGENTS.md' | head -1)"
  [ -n "$backup_file" ]
  [ "$(cat "$backup_file")" = "user content" ]
}

@test "init-project 不带 --force 保留既有项目卡片" {
  mkdir -p "$TARGET/openspec"
  echo "user card" > "$TARGET/openspec/project.md"
  echo "user context" > "$TARGET/CONTEXT.md"
  run bash "$SCRIPTS_DIR/init-project.sh" --name demo "$TARGET"
  [ "$status" -eq 0 ]
  [ "$(cat "$TARGET/openspec/project.md")" = "user card" ]
  [ "$(cat "$TARGET/CONTEXT.md")" = "user context" ]
  grep -q 'SKIP' <<<"$output"
}
