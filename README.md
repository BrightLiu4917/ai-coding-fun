# AI 全栈控制系统

一套可安装到业务项目中的 AI 工程控制系统。目标不是让 AI 自由发挥，而是把需求、设计、数据库、接口、代码、测试和发布审查变成**可确认、可审查、可验证、可回滚**的流程。

```text
你说需求 → AI 影响探测判级 → 你确认（规格 + 验收用例）→ AI 实现
→ 测试自动回填用例状态 → 发布门禁 + 独立二审 → 交付
```

## 核心特性

- **测试用例前置**：验收用例在设计阶段随规格一起经你确认，是"验收契约"；实现后由 JUnit 报告**自动回填**通过/失败状态，AI 无法"没跑就填通过"；发布门禁拦截未回填用例。
- **梯度流程**：小需求走 lite 快速通道（3 个轻量文件、30 秒确认）；碰数据库/接口/权限自动强制完整流程，门禁拦截偷渡。
- **数据安全两阶段确认**：表结构设计审查 → 数据库变更确认包 → 你点头才执行 SQL；DROP/TRUNCATE 默认先备份。
- **多工具通用**：Codex / Kimi Code / Cursor 原生读 AGENTS.md；Claude Code 获得原生自动委派 subagent + skill；WorkBuddy 获得 SKILL.md 技能包。一份源，自动生成全部适配。
- **自然语言驱动**：在 AI 应用里不需要记命令，说人话即可；AI 按意图路由表执行，判级基于代码影响探测而非措辞猜测。
- **二审模型随便换**：OpenAI 兼容端点 / Claude 官方 API / 本机 `claude`/`codex` CLI（复用订阅免 key）四种接法，`review.env` 一行切换；输出机读 `VERDICT`，BLOCK 直接拦下发布。
- **自带质量保障**：82 个 bats 回归测试 + GitHub CI；SQL 语句级安全检查；独立二审外发内容有敏感文件排除和密钥扫描。

## 30 秒上手

```bash
# 1. 安装到你的项目（非交互式；交互式用 setup-control-system.sh）
bash control/scripts/bootstrap-new-project.sh --project-dir /path/to/project --profile auto --review

# 2. 进入项目，日常只用 4 个命令
cd /path/to/project
./ai new login-jwt        # 建变更骨架（小需求加 --lite）
./ai check login-jwt      # 校验是否可请求确认
./ai test login-jwt       # 跑测试 + 自动回填用例状态
./ai ship login-jwt       # 发布门禁 + 独立二审
```

可选：`./ai install-cli` 把 `ai` 装到 `~/.local/bin`，之后免 `./` 前缀。

**在 Claude / Codex / Kimi / WorkBuddy 里连命令都不用记**，直接说：

```text
你：帮我把订单列表加个导出按钮
AI：我看了代码，不碰表和接口，按 lite 建了变更单：
    【级别：lite】理由：单前端文件改动
    【验收用例】TC-01 点击导出下载文件；TC-02 空列表按钮置灰
    确认吗？
你：确认
AI：（实现 → 测试 → 用例回填）完成，可以 ship。
```

## 你唯一需要守住的两个确认点

1. **OpenSpec change（含验收测试用例）确认后，AI 才能写代码**；
2. **数据库变更确认包点头后，才能执行 SQL**。

其余门禁（用例未回填、SQL 危险、change 不合规、文档不同步）全部由脚本自动拦截。

## 工作流

```text
                    ┌─ lite（不碰 DB/API/权限）: proposal + tasks + test-cases，30 秒确认
你提需求 → 影响探测判级 ┤
                    └─ 完整: proposal + design + tasks + test-cases + spec
                         ├─ 涉及 DB → 表结构设计审查 → 变更确认包 → 你确认
                         └─ 涉及接口/页面 → API 契约 / UI 设计确认
→ 你确认 → AI 按最小切片实现（测试方法名带用例 ID，如 test_TC01_xxx）
→ ./ai test：跑测试，JUnit 报告自动回填用例状态
→ ./ai ship：用例回填门禁 + 独立二审 + 发布必查项
```

lite 有硬门禁：影响范围声明了数据库表或 API 契约时，`impact-check` 直接失败并要求升级完整流程。

## 多工具接入

| 工具 | 契约 | 角色 | 流程技能 | 需要做什么 |
|---|---|---|---|---|
| AI 助手 | AGENTS.md 自动加载 | 手册按需读取 | — | 装完即用 |
| Kimi Code | AGENTS.md 自动加载 | 手册按需读取 | — | 装完即用 |
| Cursor | AGENTS.md 自动加载 | 手册按需读取 | — | 装完即用 |
| Claude Code | CLAUDE.md 自动加载 | `.claude/agents/` 原生自动委派 | `.claude/skills/` 3 个 | 安装时自动生成，零操作 |
| WorkBuddy | 总契约技能 | `workbuddy-skills/` 7 个 SKILL.md（自包含：规则全文内嵌，空工作区也有完整约束） | 同左 | 复制到 `~/.workbuddy/skills/` 重启；规则更新后需重新复制 |

改了规则后运行 `./ai sync` 重新生成全部适配文件；生成物默认不覆盖你手改过的文件。

## 核心架构

```text
AGENTS.md              总契约：安全红线、任务分级、意图路由、高层入口（由脚本从 control/AGENTS.md 生成）
control/openspec/      产品、需求、规格、变更、归档的事实源
control/agents/        6 个角色手册（规格/架构/DBA/开发/测试/发布）
control/rules/         工程规则层（单层编号：10-db、20-api、41-spring-boot 等，见 rules/README.md）
control/docs/          给人读的中文文档 + ADR + 系统说明
control/scripts/       安装、检查、测试、用例同步、独立二审、适配导出
control/templates/     change 五件套模板、CI 模板、ai 命令模板
control/tests/         82 个 bats 回归测试
control/tools/         确定性工具（CRUD 预览生成器）
control/examples/      3 个完整落地示例（含已回填的测试用例）
control/profiles/      按技术栈安装的 profile
```

安装后这些资产位于目标项目 `.ai-control/control/` 下；`AGENTS.md`、`CONTEXT.md`、`openspec/`、`./ai` 在项目根。

## Agent 分工（6 个角色）

| Agent | 中文角色 | 用途 |
|-------|----------|------|
| `agent-spec` | 产品规格工程师 | 需求澄清、业务建模、OpenSpec 提案/执行/归档、API 契约 |
| `agent-architect` | 系统架构师 | 架构、影响范围、重构切片 |
| `agent-dba` | 数据库工程师 | 表结构、SQL、迁移、回滚、两阶段确认 |
| `agent-dev` | 开发工程师 | Java/Go/PHP 后端、Vue/React 前端、UI 交互、CRUD 脚手架（按栈读对应章节和规则） |
| `agent-test` | 测试工程师 | **设计期写验收用例 + 实现后执行回填**（两阶段） |
| `agent-release` | 发布审查工程师 | 独立二审、安全/性能必查项、上线前审查 |

## 安装方式

```bash
# 交互式向导（推荐首次使用）
bash control/scripts/setup-control-system.sh

# 非交互式
bash control/scripts/bootstrap-new-project.sh --project-dir /path/to/project --profile auto --review

# 直接安装（可 --dry-run 预览）
bash control/scripts/install-to-project.sh --dry-run --profile default /path/to/project
bash control/scripts/install-to-project.sh --backup --profile fullstack-admin /path/to/project
```

安装是安全的：冲突预检在拷贝前进行，已有文件默认不覆盖，`--backup` 落带时间戳的备份目录。

**升级**：控制系统出新版后，在已安装项目里运行 `./ai upgrade --source /path/to/控制系统仓库`——只更新框架文件（`.ai-control/control/`、AGENTS.md、`./ai`），不碰 openspec/、CONTEXT.md、project.env 等用户数据，升级前自动备份可回退。版本记录在 `control/VERSION`。

## 自动检查与测试

```bash
bash control/scripts/run-control-tests.sh                 # 82 个 bats 回归测试
bash control/scripts/agent-check.sh                       # agent 手册规范
bash control/scripts/route-check.sh                       # 路由一致性
bash control/scripts/docs-link-check.sh                   # 文档引用有效性
bash control/scripts/sync-agents-md.sh --check            # AGENTS.md 同步校验
bash control/scripts/openspec-check.sh openspec/changes/<id>   # change 聚合校验
bash control/scripts/openspec-conflict-check.sh           # 跨 change 冲突
bash control/scripts/sql-safety-check.sh <file.sql>       # SQL 语句级安全检查
bash control/scripts/spec-drift-check.sh openspec/changes/<id>  # 规格与代码反向比对（ship 时自动跑）
```

仓库自带 GitHub CI（`.github/workflows/ci.yml`）：shell 语法 + shellcheck、五项自检、bats 全量。目标项目 CI 模板见 `control/templates/ci/`。

## 文档

- **[使用手册](control/docs/使用手册.md)** ← 详细使用指南，从安装到日常开发全流程
- [快速开始](control/docs/快速开始.md)
- [不同项目如何接入](control/docs/不同项目如何接入.md)
- [二审使用说明](control/docs/二审使用说明.md)
- [流程图](control/docs/流程图.md)
- [环境依赖](control/docs/环境依赖.md)
- [改进记录](CHANGELOG.md)

## 核心原则

- OpenSpec 管事实源；测试用例是验收契约。
- 不清楚就停止并询问，禁止猜测业务规则。
- 非简单任务先进入 OpenSpec；小需求走 lite，但门禁不豁免。
- 数据库写操作必须经两阶段确认。
- 实现必须有验证；用例状态由测试报告回填，不由 AI 手填。
- 交付前必须过发布门禁和审查。
