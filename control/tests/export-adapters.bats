#!/usr/bin/env bats
# export-adapters.sh：多工具适配导出

load test_helper

setup() {
  PROJ="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$PROJ/.ai-control/control"
  cp -R "$REPO_ROOT/control/agents" "$PROJ/.ai-control/control/"
  cp -R "$REPO_ROOT/control/rules" "$PROJ/.ai-control/control/"
  mkdir -p "$PROJ/.ai-control/control/scripts"
  cp "$SCRIPTS_DIR/export-adapters.sh" "$PROJ/.ai-control/control/scripts/"
  cp "$REPO_ROOT/control/AGENTS.md" "$PROJ/AGENTS.md"
}

@test "生成 CLAUDE.md 且引用 AGENTS.md" {
  run bash "$PROJ/.ai-control/control/scripts/export-adapters.sh" "$PROJ"
  [ "$status" -eq 0 ]
  grep -q '@AGENTS.md' "$PROJ/CLAUDE.md"
}

@test "6 个 agent 全部导出为 Claude subagent 且带 description" {
  bash "$PROJ/.ai-control/control/scripts/export-adapters.sh" "$PROJ" >/dev/null
  count="$(ls "$PROJ/.claude/agents/" | wc -l | tr -d ' ')"
  [ "$count" -eq 6 ]
  head -3 "$PROJ/.claude/agents/agent-dba.md" | grep -q '^description: '
  grep -q 'use proactively' "$PROJ/.claude/agents/agent-dba.md"
}

@test "生成三个 Claude skills" {
  bash "$PROJ/.ai-control/control/scripts/export-adapters.sh" "$PROJ" >/dev/null
  [ -f "$PROJ/.claude/skills/openspec-feature/SKILL.md" ]
  [ -f "$PROJ/.claude/skills/openspec-ready/SKILL.md" ]
  [ -f "$PROJ/.claude/skills/release-review/SKILL.md" ]
}

@test "生成 WorkBuddy 技能包含总契约" {
  bash "$PROJ/.ai-control/control/scripts/export-adapters.sh" "$PROJ" >/dev/null
  [ -f "$PROJ/workbuddy-skills/ai-control-contract/SKILL.md" ]
  grep -q '^tags:' "$PROJ/workbuddy-skills/ai-control-contract/SKILL.md"
  count="$(ls "$PROJ/workbuddy-skills/" | wc -l | tr -d ' ')"
  [ "$count" -eq 7 ]
}

@test "WorkBuddy 技能自包含：内嵌被引用的规则快照" {
  bash "$PROJ/.ai-control/control/scripts/export-adapters.sh" "$PROJ" >/dev/null
  # dba 技能必须内嵌 DB 规则细节（脱离项目也可用）
  grep -q '规则快照' "$PROJ/workbuddy-skills/agent-dba/SKILL.md"
  grep -q 'pk_id' "$PROJ/workbuddy-skills/agent-dba/SKILL.md"
  grep -q '重新复制本技能目录' "$PROJ/workbuddy-skills/agent-dba/SKILL.md"
  # 契约技能同样自包含
  grep -q '规则快照' "$PROJ/workbuddy-skills/ai-control-contract/SKILL.md"
  # Claude 侧保持引用式，不内嵌
  ! grep -q '规则快照' "$PROJ/.claude/agents/agent-dba.md"
}

@test "幂等：二次运行不覆盖，--force 才覆盖" {
  bash "$PROJ/.ai-control/control/scripts/export-adapters.sh" "$PROJ" >/dev/null
  echo "用户手改" >> "$PROJ/CLAUDE.md"
  run bash "$PROJ/.ai-control/control/scripts/export-adapters.sh" "$PROJ"
  grep -q 'EXPORT_WRITTEN=0' <<<"$output"
  grep -q '用户手改' "$PROJ/CLAUDE.md"
  run bash "$PROJ/.ai-control/control/scripts/export-adapters.sh" --force "$PROJ"
  grep -q 'EXPORT_SKIPPED=0' <<<"$output"
  ! grep -q '用户手改' "$PROJ/CLAUDE.md"
}

@test "未安装控制系统时给出明确报错" {
  rm "$PROJ/AGENTS.md"
  run bash "$PROJ/.ai-control/control/scripts/export-adapters.sh" "$PROJ"
  [ "$status" -eq 1 ]
  grep -q 'AGENTS.md' <<<"$output"
}
