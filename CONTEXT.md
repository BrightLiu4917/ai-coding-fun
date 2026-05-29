# 项目上下文

本文件记录 AI 全栈控制系统自己的领域语言。它不是业务项目的需求文档，也不是接口文档；复制到具体业务项目后，应替换或扩展为该项目真实领域语言。

## 语言

**OpenSpec**:
产品目标、业务规则、能力规格、变更提案、设计说明、任务清单和归档记录的事实源。
_避免_: 把聊天记录、临时清单或未确认建议当作 OpenSpec 事实。

**Change**:
一次待确认的非简单变更，位于 `openspec/changes/<change-id>/`，通常包含 `proposal.md`、`design.md`、`tasks.md` 和 specs delta。
_避免_: 把 change 当成已经上线或已经归档的事实。

**Spec**:
已经确认并归档的能力规格，位于 `openspec/specs/<capability>/spec.md`。
_避免_: 把未确认规则直接写成 Spec。

**Archive**:
实现、验证和审查完成后，将已确认行为从 change 整理到 specs 的动作。
_避免_: 只改代码不沉淀事实源。

**Capability**:
可独立描述、变更和验收的能力。它可以是业务能力，也可以是本控制系统的安装、路由、检查、代码生成等工程能力。
_避免_: 在讨论规格时混用 module、feature、page，除非确实指代码模块、功能点或页面。

**Actor**:
执行任务或使用系统的角色。对本仓库而言，常见 Actor 包括产品负责人、工程师、DBA、QA、审查者和 Codex。
_避免_: 需要区分职责时只说 user。

**Workflow**:
由入口、步骤、状态、确认点和输出组成的流程，例如 OpenSpec 提案流程、安装流程、发布审查流程。
_避免_: 用 process 泛称会影响责任边界的工作流。

**Contract**:
必须保持兼容的约定，包括 API、字段、响应结构、脚本参数、profile 格式和 agent 发现结构。
_避免_: 把兼容约束只写成口头说明。

**Agent**:
位于 `agents/agent-<name>.md` 的专项执行规则。agent 负责角色化执行，不替代 OpenSpec 事实源。
_避免_: 一个 agent 同时负责多个语言、框架或流程阶段。

**Agent Route**:
根据任务类型选择 agent 的规则，包括顺序、并行、循环、回退和冲突处理，事实源为 `docs/AGENT_ROUTING.md`。
_避免_: 在多个文档里维护互相冲突的路由规则。

**Codegen Adapter**:
面向特定项目约定的代码生成适配器。Java Spring Boot CRUD 生成必须先由 `agent-codegen` 识别 adapter，再进入具体 adapter 或经确认转入手写实现。
_避免_: 把某个项目专用脚手架描述成通用脚手架。

**Generic Adapter**:
理论上的通用 Java Spring Boot CRUD adapter。当前仓库只保留占位说明，尚未提供可执行通用生成器。
_避免_: 在 generic adapter 未实现时默认生成 CRUD 代码。

**Gupo Adapter**:
只适用于 gupo 项目封装、包结构、返回体、分页、异常、DTO/VO 和 Mapper/XML 约定的 Java Spring Boot CRUD adapter。
_避免_: 仅凭 Spring Boot、MyBatis 或 MyBatis-Plus 就选择 gupo adapter。

**Adapter Confirmation**:
编码或生成前确认目标项目应使用哪个 codegen adapter，以及 adapter 不可用时是否允许生产级手写实现的确认点。
_避免_: adapter 不明确时继续生成、手写或迁移代码。

**Profile**:
安装 profile，位于 `profiles/<name>/profile.toml`，声明安装脚本应复制哪些控制系统文件。
_避免_: 在安装脚本里硬编码所有安装组合。

**Review Gate**:
进入发布前必须通过的审查门，包括生产审查、安全、性能、测试和发布准备检查。
_避免_: 用“看起来没问题”替代可定位、可复现的审查结论。

## 关系

- 一个 **Change** 描述一次非简单变更；确认前不能进入实现。
- 一个 **Change** 可以修改一个或多个 **Spec**。
- **Archive** 把已完成并确认的 **Change** 沉淀为 **Spec**。
- 一个 **Capability** 通常包含一个或多个 **Workflow**。
- 一个 **Workflow** 由一个或多个 **Actor** 执行。
- **Contract** 连接脚本、文档、agent、API、前端、后端和外部系统。
- **Agent Route** 决定哪些 **Agent** 参与，以及它们是否可并行。
- **Codegen Adapter** 是一种特殊 **Agent Route** 决策，先做 **Adapter Confirmation**，再进入 **Generic Adapter**、**Gupo Adapter** 或手写实现路径。
- **Profile** 决定安装脚本复制哪些控制系统资产。
- **Review Gate** 在交付前检查 OpenSpec、代码、数据、安全、性能和验证证据是否一致。

## 示例对话

> **工程师:** "这次只是补安装脚本和 profile，要不要进 OpenSpec？"
> **Codex:** "会新增脚本和目录结构，属于非简单任务。先创建 **Change**，确认范围不涉及 DB/API 后再实现。"

> **工程师:** "目标项目只想安装规则文档和 agents。"
> **Codex:** "这属于安装 **Profile** 的选择，可以使用 `profiles/minimal/profile.toml`，或用 `--only` 明确安装条目。"

> **工程师:** "这个 Spring Boot 项目能直接生成 CRUD 吗？"
> **Codex:** "先做 **Adapter Confirmation**。当前只有 **Gupo Adapter** 可执行；如果不是 gupo 项目，不能套用该 adapter。"

## 已标记歧义

- 目标业务项目复制本仓库后，应补充自己的业务 Actor、Capability、Workflow、状态枚举、权限和租户模型。
- 本仓库只定义控制系统术语，不替代目标项目真实业务事实。
