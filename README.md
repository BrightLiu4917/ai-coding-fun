# AI 全栈控制系统

[![CI](https://github.com/BrightLiu4917/ai-coding-fun/actions/workflows/ci.yml/badge.svg)](https://github.com/BrightLiu4917/ai-coding-fun/actions/workflows/ci.yml)
![version](https://img.shields.io/badge/version-1.0.0-blue)
![tests](https://img.shields.io/badge/bats-78%20passed-brightgreen)
![tools](https://img.shields.io/badge/AI%20tools-Codex%20%7C%20Claude%20%7C%20Kimi%20%7C%20Cursor%20%7C%20WorkBuddy-8A2BE2)

**一套安装到业务项目里的 AI 工程控制系统**：把 AI 开发从"祈祷式生成"变成**可确认、可审查、可验证、可回滚**的工程流程。

```text
你说需求 → AI 影响探测判级 → 你确认（规格 + 验收用例）→ AI 实现
→ 测试（JUnit 报告即证据）→ 秒级发布门禁 → 交付（高风险可选独立二审）
```

---

## 目录

- [为什么需要它](#为什么需要它)
- [30 秒上手](#30-秒上手)
- [核心概念](#核心概念)
- [工作流详解](#工作流详解)
- [多工具接入](#多工具接入)
- [命令参考](#命令参考)
- [安装与升级](#安装与升级)
- [架构与目录](#架构与目录)
- [质量保障](#质量保障)
- [文档索引](#文档索引)

---

## 为什么需要它

直接让 AI 写业务代码，通常会遇到四类事故：

| 事故 | 本系统的对策 |
|---|---|
| AI 猜测业务规则，发明字段、枚举、API 路径 | **规格先行**：change 未经你确认，禁止写码（契约红线 + 检查脚本双重拦截） |
| AI 实现完自己宣布"测试通过" | **报告即证据**：验收用例随规格一起经你确认；发布门禁**直查 JUnit 报告**（存在、无失败、TC-ID 覆盖），AI 无法谎报"通过" |
| AI 顺手执行了危险 SQL | **数据库两阶段确认**：表结构设计审查 → 变更确认包 → 你点头才执行；DROP/TRUNCATE 默认先备份 |
| 小改动也被流程拖死，最终没人守流程 | **梯度防御**：lite 快速通道 30 秒确认；碰数据库/接口/权限自动强制完整流程，门禁拦截偷渡 |

设计哲学一句话：**AI 的自由度和改动的风险成反比**——改文案随便干，动数据库层层确认。

## 30 秒上手

```bash
# 1. 安装到你的项目
bash control/scripts/bootstrap-new-project.sh --project-dir /path/to/project --profile auto --review

# 2. 日常只用 4 个命令
cd /path/to/project
./ai new login-jwt        # 建变更骨架（小需求：./ai new fix-typo --lite）
./ai check login-jwt      # 校验是否可请求确认
./ai test login-jwt       # 跑测试（JUnit 报告即验收证据）
./ai ship login-jwt       # 秒级发布门禁（高风险可加 --review 独立二审）
```

**在 AI 应用（Claude Code / Codex / Kimi / Cursor / WorkBuddy）里连命令都不用记**，说人话即可：

```text
你：帮我把订单列表加个导出按钮
AI：我看了代码，不碰表和接口，按 lite 建了变更单：
    【级别：lite】理由：单前端文件改动
    【验收用例】TC-01 点击导出下载文件；TC-02 空列表按钮置灰
    确认吗？
你：确认
AI：（实现 → 测试全绿）完成，ship 门禁秒过。
```

> 可选：`./ai install-cli` 安装全局 `ai` 命令到 `~/.local/bin`，免 `./` 前缀。

## 核心概念

### 你只需守住两个确认点

| 确认点 | 你确认什么 | 不确认会怎样 |
|---|---|---|
| **① OpenSpec change** | 需求理解、验收用例覆盖、判级合理性 | AI 禁止写代码 |
| **② 数据库变更确认包** | 目标 DDL、回滚 SQL、联动改动 | AI 禁止执行任何 SQL |

其余门禁（用例证据缺失、SQL 危险、change 不合规、规格漂移、文档不同步）全部由脚本自动拦截。

### 6 个工程角色

AI 按角色工作，路由自动衔接（详见 [AGENT_ROUTING](control/docs/AGENT_ROUTING.md)）：

| 角色 | 职责 |
|---|---|
| `agent-spec` 产品规格工程师 | 需求澄清、业务建模、OpenSpec、API 契约 |
| `agent-architect` 系统架构师 | 架构、影响范围、重构切片 |
| `agent-dba` 数据库工程师 | 表结构、SQL、迁移回滚、两阶段确认 |
| `agent-dev` 开发工程师 | Java/Go/PHP 后端、Vue/React 前端、UI、CRUD 脚手架（按栈加载规则） |
| `agent-test` 测试工程师 | **两阶段**：设计期写验收用例 + 实现后按报告核对证据（goal-backward，独立上下文） |
| `agent-release` 发布审查工程师 | 独立二审、安全/性能必查项、上线前审查 |

### 测试用例是"验收契约"

```text
设计期   test-cases.md 随规格一起经你确认（用例先于代码存在）
实现期   测试方法名带用例 ID：test_TC01_分页查询
发布期   ship 门禁直查 JUnit 报告：存在 + 无失败 + TC-ID 覆盖全部非手动用例
手动用例 执行结果逐条写入交付说明（不维护状态表格）
```

AI 无法"没跑就说通过"——证据是测试框架生成的报告，不是 AI 维护的表格。

## 工作流详解

```text
                    ┌─ lite（不碰 DB/API/权限）: proposal + tasks + test-cases，30 秒确认
你提需求 → 影响探测判级 ┤
                    └─ 完整: proposal + tasks + test-cases + spec（design 跨模块/DB 时才建）
                         ├─ 涉及 DB → 表结构设计审查 → 变更确认包 → 你确认②
                         └─ 涉及接口/页面 → API 契约 / UI 设计确认
→ 你确认① → AI 按最小切片实现（验证在独立上下文进行，goal-backward 倒推验证点）
→ ./ai test：跑测试，JUnit 报告即验收证据
→ ./ai ship：证据核对 + 规格防漂移，秒级完成
   高风险（碰 DB/权限/支付）→ 提示建议 --review 独立二审（VERDICT 机读，BLOCK 拦截）
```

**lite 有硬门禁**：影响范围声明了数据库表或 API 契约时，`impact-check` 直接失败并要求升级完整流程——快速通道不是逃生通道。

**独立二审**四种接法（配置 `.agent/review.env`，详见[二审使用说明](control/docs/二审使用说明.md)）：

| `REVIEW_PROVIDER` | 说明 |
|---|---|
| `openai-compatible`（默认） | DeepSeek / Kimi / 通义 / GLM / GPT / Ollama 等任何兼容端点 |
| `anthropic` | Claude 官方 Messages API |
| `claude-cli` / `codex-cli` | 本机 CLI 无头模式，**复用订阅免 API key**，天然独立会话 |

**二审默认不跑**（按需外援）：`ai ship --review` 主动触发，或 `REVIEW_MODE=always` 恢复每次必审。外发安全自动生效：敏感文件排除、密钥扫描中止、diff 超限截断、key 不落命令行。

## 多工具接入

一份源，自动生成全部适配；改规则后 `./ai sync` 一键重新生成：

| 工具 | 契约加载 | 角色机制 | 需要做什么 |
|---|---|---|---|
| Codex / Kimi / Cursor | `AGENTS.md` 原生自动读取 | 手册按路由表读取 | **装完即用** |
| Claude Code | `CLAUDE.md`（自动生成） | `.claude/agents/` **原生自动委派** + 3 个 skill | **零操作**，安装时自动生成 |
| WorkBuddy | 总契约技能 | `workbuddy-skills/` 7 个自包含 SKILL.md（规则全文内嵌，空工作区可用） | 复制到 `~/.workbuddy/skills/` 重启；规则更新后重新复制 |

## 命令参考

日常入口 `./ai`（其余底层脚本见[使用手册](control/docs/使用手册.md#命令参考)）：

| 命令 | 作用 |
|---|---|
| `./ai new <id> [--lite\|--upgrade]` | 建变更骨架（lite 快速通道；--upgrade 把 lite 升级为完整流程且保留已写内容） |
| `./ai check <id>` | change 合规校验（影响范围/路由闭环/用例覆盖/待确认问题） |
| `./ai test [<id>]` | 跑测试（JUnit 报告即验收证据） |
| `./ai ship <id> [--review]` | 秒级门禁：JUnit 证据 + 防漂移；--review 加独立二审 |
| `./ai sync` | 重新生成全部工具适配文件 |
| `./ai upgrade [--source <仓库>]` | 升级框架（不碰用户数据，自动备份） |
| `./ai doctor` | 环境体检 |
| `./ai install-cli` | 安装全局 `ai` 命令 |

## 安装与升级

```bash
# 交互式向导（推荐首次）
bash control/scripts/setup-control-system.sh

# 非交互式
bash control/scripts/bootstrap-new-project.sh --project-dir /path/to/project --profile auto --review

# 直接安装（--dry-run 可预览）
bash control/scripts/install-to-project.sh --dry-run --profile default /path/to/project
bash control/scripts/install-to-project.sh --backup --profile fullstack-admin /path/to/project
```

安装安全性：冲突预检在拷贝前进行；已有文件默认不覆盖；`--backup` 落带时间戳备份目录。

**升级**：`./ai upgrade --source /path/to/本仓库` 只更新框架文件（`.ai-control/control/`、AGENTS.md、`./ai`），**绝不触碰** `openspec/`、`CONTEXT.md`、`project.env`、`.agent/`；升级前自动备份，可一条命令回退。版本见 [control/VERSION](control/VERSION)。

## 架构与目录

```text
安装后的目标项目/
├── AGENTS.md            总契约（红线/分级/意图路由）— Codex/Kimi/Cursor 自动读
├── CLAUDE.md  .claude/  Claude Code 适配（自动生成）
├── ai                   统一命令入口
├── openspec/            事实源：changes/（变更五件套）+ specs/（归档规格）← 你只看这里
├── workbuddy-skills/    WorkBuddy 技能包（自动生成）
├── .agent/              本地运行数据：review.env、日志、审查记录（gitignore）
└── .ai-control/control/ 系统本体 ← 你不需要打开
    ├── agents/          6 个角色手册
    ├── rules/           规则层（单层编号：10-db-schema、20-api、41-spring-boot…）
    ├── scripts/         检查、测试、二审、导出、升级
    ├── templates/       变更模板、CI 模板
    └── tests/           78 个 bats 回归测试
```

分层原则：**契约（每次对话必加载）→ 角色（按任务自动委派）→ 规则（按需读取）**——约束全生效且不撑爆上下文。规则只在 `rules/` 单处维护，所有工具适配物由脚本从这份源生成，禁止手改生成物（有同步校验兜底）。

## 质量保障

系统自身的工程质量由三层验证保证，全部挂在 CI：

```bash
bash control/scripts/run-control-tests.sh    # 78 个 bats 回归测试（含每个已修 bug 的回归用例）
shellcheck control/scripts/**/*.sh           # 静态检查 0 告警
bash control/scripts/agent-check.sh          # 手册规范 / route-check 路由 / docs-link-check 引用
bash control/scripts/sync-agents-md.sh --check   # 生成物与源同步校验
```

对目标项目的检查能力：SQL 语句级安全分析（跨行/注释/字符串感知）、影响范围五字段校验、声明⇒任务闭环、跨 change 冲突检测、规格防漂移反向比对、用例证据门禁（直查 JUnit 报告）。

## 文档索引

| 文档 | 内容 |
|---|---|
| **[使用手册](control/docs/使用手册.md)** | 从安装到日常开发的完整指南（推荐通读一次） |
| [快速开始](control/docs/快速开始.md) / [新项目快速接入](control/docs/新项目快速接入.md) | 上手路径 |
| [如何提需求](control/docs/如何提需求.md) | 给 AI 提需求的正确姿势 |
| [二审使用说明](control/docs/二审使用说明.md) | 独立二审配置、四种 provider、故障排查 |
| [不同项目如何接入](control/docs/不同项目如何接入.md) / [环境依赖](control/docs/环境依赖.md) | 适配与环境 |
| [流程图](control/docs/流程图.md) | 全流程 mermaid 图 |
| [CHANGELOG](CHANGELOG.md) | 十四批改进的完整记录 |

## 核心原则

1. OpenSpec 管事实源；测试用例是验收契约。
2. 不清楚就停止并询问，禁止猜测业务规则。
3. 非简单任务先进入 OpenSpec；小需求走 lite，门禁不豁免。
4. 数据库写操作必须经两阶段确认。
5. 验收以原始证据为准：JUnit 报告 + 交付说明，不维护二手状态表。
6. 交付前必须过秒级发布门禁；高风险变更建议独立二审。
