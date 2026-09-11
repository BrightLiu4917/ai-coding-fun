#!/usr/bin/env bash
set -euo pipefail

# 多工具适配导出：把控制系统的契约和 agent 手册导出为各 AI 编码工具的原生格式。
#
# 生成物（在项目根）：
#   CLAUDE.md                       Claude Code 契约入口（@AGENTS.md import）
#   .claude/agents/agent-*.md       Claude Code 原生 subagent（按 description 自动委派）
#   .claude/skills/<name>/SKILL.md  Claude Code skills（包装 ai-dev.sh 流程）
#   workbuddy-skills/<name>/SKILL.md  WorkBuddy 技能包（复制到 ~/.workbuddy/skills/ 使用）
#
# Codex 与 Kimi Code 原生自动加载 AGENTS.md，无需导出。
# 幂等：已存在的文件默认跳过；--force 覆盖重新生成。
#
# 用法：export-adapters.sh [--force] [project-root]

FORCE=0
TARGET_ROOT=""
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    *) TARGET_ROOT="$arg" ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
fi
[[ -n "$TARGET_ROOT" ]] && PROJECT_ROOT="$(cd "$TARGET_ROOT" && pwd)"

AGENTS_DIR="$ROOT/agents"
AGENTS_MD="$PROJECT_ROOT/AGENTS.md"

if [[ ! -d "$AGENTS_DIR" ]]; then
  echo "未找到 agent 手册目录: $AGENTS_DIR" >&2
  exit 1
fi
if [[ ! -f "$AGENTS_MD" ]]; then
  echo "未找到 $AGENTS_MD；请先安装控制系统（bootstrap-new-project.sh / install-to-project.sh）" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for export-adapters" >&2
  exit 1
fi

export EXPORT_FORCE="$FORCE"
RULES_DIR="$ROOT/rules"
python3 - "$AGENTS_DIR" "$AGENTS_MD" "$PROJECT_ROOT" "$RULES_DIR" <<'PY'
import os
import re
import sys

agents_dir, agents_md, project_root = sys.argv[1], sys.argv[2], sys.argv[3]
rules_dir = sys.argv[4] if len(sys.argv) > 4 else ""
force = os.environ.get("EXPORT_FORCE") == "1"

skipped = []
written = []

def write(path, content):
    if os.path.exists(path) and not force:
        skipped.append(os.path.relpath(path, project_root))
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    written.append(os.path.relpath(path, project_root))

def section(content, title):
    m = re.search(rf"^## {title}\n(.*?)(?=^## |\Z)", content, re.M | re.S)
    return m.group(1).strip() if m else ""

def first_sentence(text):
    text = text.strip().splitlines()[0] if text.strip() else ""
    return text.rstrip("。") + "。" if text else ""

def scenario_summary(content, limit=3):
    body = section(content, "适用场景")
    items = [re.sub(r"^-\s*", "", l).strip().rstrip("。") for l in body.splitlines() if l.strip().startswith("-")]
    return "；".join(items[:limit])

# ---------- 1. CLAUDE.md ----------
write(os.path.join(project_root, "CLAUDE.md"),
"""# 项目契约入口（Claude Code）

本项目使用 AI 全栈控制系统，全部契约、红线和流程见 AGENTS.md：

@AGENTS.md

补充说明：
- 各工种的详细手册已导出为 `.claude/agents/` 原生 subagent，匹配任务时会自动委派。
- OpenSpec 流程可通过 `.claude/skills/` 中的技能触发。
""")

# ---------- 2. .claude/agents/ ----------
agent_files = sorted(f for f in os.listdir(agents_dir) if f.startswith("agent-") and f.endswith(".md"))
for name in agent_files:
    path = os.path.join(agents_dir, name)
    content = open(path, encoding="utf-8").read()
    agent_id = name[:-3]
    m = re.match(r"# ([^（\n]+)", content)
    role = m.group(1).strip() if m else agent_id
    duty = first_sentence(section(content, "职责"))
    scenes = scenario_summary(content)
    desc = f"{role}。{duty}适用：{scenes}。涉及上述场景时必须主动使用（use proactively）。"
    desc = desc.replace("\n", " ")
    front = f"---\nname: {agent_id}\ndescription: {desc}\n---\n\n"
    write(os.path.join(project_root, ".claude", "agents", name), front + content)

# ---------- 3. .claude/skills/ ----------
skills = {
    "openspec-feature": (
        "为新功能创建 OpenSpec change 骨架。用户说“加个XX”“帮我做XX”“我想要XX”“改一下XX”“开发XX功能”等提出需求时使用；先影响探测判级（lite/完整），确认单标注级别和理由。",
        """# OpenSpec 新功能流程

1. 与用户确认 change-id（小写中横线，如 login-jwt）。
2. 运行：

```bash
bash .ai-control/control/scripts/ai-dev.sh feature $ARGUMENTS
```

3. 按产品规格工程师（agent-spec）手册完善 proposal/tasks（design 仅在跨模块/数据库/接口兼容时创建）。
4. 按测试工程师（agent-test）手册设计 test-cases.md 验收用例。
5. 输出待确认问题清单，等待用户确认后才能进入实现。
""",
    ),
    "openspec-ready": (
        "校验 OpenSpec change 是否完整合规。change 写完后、请求用户确认前使用；用户说“检查一下”“写全了吗”“可以确认了吗”时也使用。",
        """# OpenSpec 就绪校验

```bash
bash .ai-control/control/scripts/ai-dev.sh ready $ARGUMENTS
```

校验失败时逐项修复后重跑；全部通过后向用户输出确认请求。
""",
    ),
    "release-review": (
        "发布前审查：跑测试、回填用例状态、独立二审。用户说“测一下”“能上线吗”“可以交付吗”“发布”时使用。",
        """# 发布前审查流程

```bash
OPENSPEC_CHANGE_ID=$ARGUMENTS bash .ai-control/control/scripts/run-tests.sh
./ai ship $ARGUMENTS
```

ship 门禁：JUnit 证据核对 + 规格防漂移（秒级）。高风险变更（碰 DB/权限/支付）建议 `./ai ship $ARGUMENTS --review` 做独立二审。
然后按发布审查工程师（agent-release）手册逐项过必查项（只过与本次变更相关的项）。
""",
    ),
}
for skill_name, (desc, body) in skills.items():
    front = f"---\nname: {skill_name}\ndescription: {desc}\n---\n\n"
    write(os.path.join(project_root, ".claude", "skills", skill_name, "SKILL.md"), front + body)


# WorkBuddy 技能装在全局目录，可能在未安装控制系统的工作区被调用，
# 引用的 rules 文件路径会悬空，因此导出时把被引用规则全文内嵌为附录（快照）。
SNAPSHOT_NOTE = (
    "\n\n---\n\n# 附录：内嵌规则快照\n\n"
    "> 本技能自包含：以下规则在导出时从 control/rules/ 快照内嵌，脱离项目也可用。\n"
    "> 规则更新后需重跑 `./ai sync` 并重新复制本技能目录到 ~/.workbuddy/skills/。\n"
    "> 正文中的脚本命令仅在安装了控制系统的项目内可执行。\n\n"
)

def embed_rules(content):
    if not rules_dir or not os.path.isdir(rules_dir):
        return content
    refs = list(dict.fromkeys(re.findall(r"\.ai-control/control/rules/([0-9A-Za-z._-]+\.md)", content)))
    parts = []
    for name in refs:
        path = os.path.join(rules_dir, name)
        if os.path.isfile(path):
            parts.append(f"## 规则快照：{name}\n\n" + open(path, encoding="utf-8").read().strip() + "\n")
    if not parts:
        return content
    return content + SNAPSHOT_NOTE + "\n".join(parts)

# ---------- 4. workbuddy-skills/ ----------
agents_md_content = open(agents_md, encoding="utf-8").read()
contract_front = (
    "---\n"
    "name: ai-control-contract\n"
    "description: AI 全栈控制系统总契约：安全红线、任务分级、OpenSpec 流程、数据安全。本项目内任何开发任务开始前必须先应用本技能。\n"
    "version: 1.0.0\n"
    "tags: contract, openspec, workflow\n"
    "---\n\n"
)
write(os.path.join(project_root, "workbuddy-skills", "ai-control-contract", "SKILL.md"),
      contract_front + embed_rules(agents_md_content))

for name in agent_files:
    path = os.path.join(agents_dir, name)
    content = open(path, encoding="utf-8").read()
    agent_id = name[:-3]
    m = re.match(r"# ([^（\n]+)", content)
    role = m.group(1).strip() if m else agent_id
    duty = first_sentence(section(content, "职责"))
    scenes = scenario_summary(content)
    front = (
        "---\n"
        f"name: {agent_id}\n"
        f"description: {role}。{duty}适用：{scenes}。\n"
        "version: 1.0.0\n"
        f"tags: ai-control, {agent_id.replace('agent-', '')}\n"
        "---\n\n"
    )
    write(os.path.join(project_root, "workbuddy-skills", agent_id, "SKILL.md"), front + embed_rules(content))

print(f"EXPORT_WRITTEN={len(written)} EXPORT_SKIPPED={len(skipped)}")
for p in written:
    print(f"  + {p}")
if skipped:
    print("已存在跳过（--force 可覆盖）:")
    for p in skipped:
        print(f"  = {p}")
print()
print("WorkBuddy 使用方式：把 workbuddy-skills/ 下的目录复制到 ~/.workbuddy/skills/ 后重启 WorkBuddy。")
print("Codex / Kimi Code 原生读取 AGENTS.md，无需额外操作。")
PY
