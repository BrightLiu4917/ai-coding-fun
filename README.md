# AI 全栈控制系统

一套可复制到业务项目中的 AI 全栈工程控制系统。目标不是让 AI 自由发挥，而是把需求、设计、数据库、接口、代码、测试、二审和发布审查变成可确认、可审查、可回滚的流程。

当前主流程：

```text
Codex App + OpenSpec + deepv4
```

## 适用场景

- SaaS、后台管理、B2B 系统、内部运营系统。
- Java / Spring Boot / MyBatis / MySQL 后端项目。
- Vue / React 管理端前端项目。
- Go / Gin、PHP / Laravel / ThinkPHP 等需要通用 AI 开发流程的项目。
- 需要 AI 参与需求澄清、架构设计、表设计、接口设计、代码实现、测试和上线审查。

## 核心架构

```text
OpenSpec = 产品、业务、需求、规格、变更和归档事实源
AGENTS.md = 总调度器，定义安全红线和高层入口
agents/ = 普通 Markdown 工程手册，按工种命名
docs/common = 跨技术栈项目适配规则
docs/stacks = Spring Boot、Vue3、React、Go、PHP 技术栈规则
docs/features = JWT、RBAC、CRUD、OpenAPI 功能规则
scripts/ = 安装、检查、测试、deepv4 二审
templates/ = 标准产物模板
tools/ = 确定性工具，例如 CRUD 预览生成器
examples/ = 落地示例
```

## 推荐目录

```text
.
├── AGENTS.md
├── CODEX_TASK_TEMPLATE.md
├── .ai-control/
├── CONTEXT.md
├── CONTEXT-MAP.md
├── openspec/
├── agents/
│   ├── agent-product.md
│   ├── agent-openspec.md
│   ├── agent-architect.md
│   ├── agent-ui.md
│   ├── agent-web.md
│   ├── agent-api.md
│   ├── agent-java.md
│   ├── agent-go.md
│   ├── agent-php.md
│   ├── agent-dba.md
│   ├── agent-codegen.md
│   ├── agent-test.md
│   ├── agent-security.md
│   ├── agent-performance.md
│   └── agent-release.md
├── docs/
├── scripts/
├── templates/
├── tools/
├── profiles/
└── examples/
```

## Agent 分工

| Agent | 中文角色 | 用途 |
|-------|----------|------|
| `agent-product` | 产品需求工程师 | 产品、业务目标、领域建模 |
| `agent-openspec` | OpenSpec 规格工程师 | OpenSpec 提案、执行、归档 |
| `agent-architect` | 系统架构师 | 架构、影响范围、重构切片 |
| `agent-ui` | UI 交互设计师 | UX/UI、交互、视觉状态 |
| `agent-web` | Web 前端开发工程师 | Vue/React 前端实现 |
| `agent-api` | API 契约工程师 | API 契约 |
| `agent-java` | Java 后端开发工程师 | Spring Boot 后端实现 |
| `agent-go` | Go 后端开发工程师 | Go / Gin 后端实现 |
| `agent-php` | PHP 后端开发工程师 | PHP 后端实现 |
| `agent-dba` | 数据库工程师 | MySQL 表结构、SQL、迁移、回滚 |
| `agent-codegen` | 代码生成工程师 | CRUD 脚手架和 adapter 判断 |
| `agent-test` | 测试工程师 | 单测、集成测试、E2E、验收 |
| `agent-security` | 安全工程师 | 安全审查 |
| `agent-performance` | 性能工程师 | 性能审查 |
| `agent-release` | 发布审查工程师 | deepv4 二审、上线前审查 |

## 标准流程

新功能：

```text
产品需求工程师（agent-product）
-> OpenSpec 规格工程师（agent-openspec）
-> 系统架构师（agent-architect），如影响范围不清
-> UI 交互设计师（agent-ui），如涉及界面
-> API 契约工程师（agent-api），如涉及接口
-> 数据库工程师（agent-dba），如涉及数据库
-> 代码生成工程师（agent-codegen），如涉及标准 CRUD 脚手架
-> Java/Go/PHP 后端开发工程师 / Web 前端开发工程师（agent-java / agent-go / agent-php / agent-web）
-> 测试工程师（agent-test）
-> 安全工程师 / 性能工程师（agent-security / agent-performance），如有风险
-> 发布审查工程师（agent-release）
```

Bug 修复：

```text
诊断和复现
-> 系统架构师（agent-architect），如调用链不清
-> 产品需求工程师（agent-product），如业务规则不清
-> 数据库工程师（agent-dba），如涉及 SQL 或数据
-> API 契约工程师（agent-api），如涉及接口
-> Java/Go/PHP 后端开发工程师 / Web 前端开发工程师（agent-java / agent-go / agent-php / agent-web）
-> 测试工程师（agent-test）
-> 发布审查工程师（agent-release）
```

数据库变更：

```text
OpenSpec 规格工程师（agent-openspec）
-> 数据库工程师（agent-dba）
-> API 契约工程师（agent-api），如影响接口
-> Java 后端开发工程师（agent-java）
-> 测试工程师（agent-test）
-> 发布审查工程师（agent-release）
```

## Codegen Adapter

CRUD 代码生成必须先走代码生成工程师（`agent-codegen`）判断 adapter。generic adapter 只生成审查预览包，不直接写入业务源码目录。

```bash
bash tools/codegen/java-springboot-crud-adapters/generic/scripts/crud-preview --help
```

真实落地业务代码必须经用户确认后转入 Java 后端开发工程师（`agent-java`）做生产级实现。

## deepv4 二审

```text
OpenSpec 已确认
-> Codex 实现最小任务切片
-> scripts/run-tests.sh
-> scripts/prepare-deepv4-review.sh
-> scripts/run-deepv4-review.sh
-> 发布审查工程师（agent-release）
```

deepv4 只做独立二审，不直接修改代码，也不能替代 OpenSpec 或用户确认。

## 安装到项目

交互式安装：

```bash
bash scripts/setup-control-system.sh
```

非交互式安装：

```bash
bash scripts/bootstrap-new-project.sh --project-dir /path/to/project --profile auto --deepv4
```

直接安装：

```bash
bash scripts/install-to-project.sh --dry-run --profile default /path/to/project
bash scripts/install-to-project.sh --backup --profile default /path/to/project
bash scripts/install-to-project.sh --backup --profile fullstack-admin /path/to/project
bash scripts/install-to-project.sh --backup --profile gupo /path/to/gupo-project
```

## 小白模式

目标项目安装完成后，优先使用统一入口：

```bash
bash scripts/ai-dev.sh init
bash scripts/ai-dev.sh feature login-jwt
bash scripts/ai-dev.sh feature login-jwt --force
bash scripts/ai-dev.sh ready login-jwt
bash scripts/ai-dev.sh test
bash scripts/ai-dev.sh review
bash scripts/ai-dev.sh next
```

`ai-dev.sh` 会把底层 OpenSpec、测试和 deepv4 命令串起来，并输出下一步该复制给 Codex 的提示。

- 不安装官方 OpenSpec CLI 也可以用；`ai-dev.sh` 会直接维护本地 `openspec/`。
- 需要官方 `openspec` 命令时，可选安装 `npm install -g @fission-ai/openspec@latest`。
- `init` 用编号选择访问控制模式；不带 `--force` 不覆盖已有项目卡片，也不静默修改已有 `.ai-control/project.env`。
- `init` 可直接配置 deepv4，启用后输入 `DEEPV4_BASE_URL`、`DEEPV4_API_KEY`、`DEEPV4_MODEL`，生成 `.agent/deepv4.env`。
- `feature <change-id>` 默认保留已有 change。
- `feature <change-id> --force` 才重生成 OpenSpec 骨架。
- `next` 按最近修改时间判断下一步要处理的 change。

## 自动检查

```bash
bash scripts/ai-dev.sh next
bash scripts/detect-project-profile.sh --write
bash scripts/check-project-ready.sh
bash scripts/agent-check.sh
bash scripts/route-check.sh
bash scripts/docs-link-check.sh
bash scripts/openspec-check.sh openspec/changes/<change-id>
bash scripts/impact-check.sh openspec/changes/<change-id>
bash scripts/route-compliance-check.sh openspec/changes/<change-id>
bash scripts/openspec-conflict-check.sh
bash scripts/run-tests.sh
```

新增 agent：

```bash
bash scripts/new-agent.sh agent-go "Go 后端开发工程师" "Go 后端实现手册，用于 Gin/GORM 项目..."
```

## 中文文档

- [使用手册](docs/使用手册.md)
- [快速开始](docs/快速开始.md)
- [不同项目如何接入](docs/不同项目如何接入.md)
- [Codex 如何提需求](docs/Codex如何提需求.md)
- [deepv4 二审使用说明](docs/deepv4二审使用说明.md)
- [流程图](docs/流程图.md)
- [环境依赖](docs/环境依赖.md)
- [新项目快速接入](docs/新项目快速接入.md)

## 核心原则

- OpenSpec 管事实源。
- `agents/` 管工程分工。
- 不清楚就停止并询问。
- 非简单任务先进入 OpenSpec。
- 数据库写操作必须确认。
- 实现必须有验证。
- 交付前必须审查。
