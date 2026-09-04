# Agent 路由规则

## 目标

让 AI 助手按少量、清晰的工程角色工作。所有 agent 放在 `agents/`，普通 Markdown 文件。

## Agent 清单（6 个角色）

对用户输出时优先使用中文角色名；需要定位文件、路由或脚本校验时，再保留 agent id。

```text
agents/agent-spec.md        # 产品规格工程师：需求澄清、业务建模、OpenSpec 提案/执行/归档、API 契约
agents/agent-architect.md   # 系统架构师：架构、影响范围、重构切片
agents/agent-dba.md         # 数据库工程师：MySQL 表结构、SQL、迁移、回滚、两阶段确认
agents/agent-dev.md         # 开发工程师：Java/Go/PHP 后端、Vue/React 前端、UI 交互、CRUD 脚手架（按栈读对应章节）
agents/agent-test.md        # 测试工程师：设计期写验收用例 + 实现后执行回填（两阶段）
agents/agent-release.md     # 发布审查工程师：独立二审、安全/性能必查项、上线前审查
```

## 快速分类

| 任务类型 | 路由 |
|----------|------|
| 新功能 / 需求不清 / OpenSpec / API 契约 | 产品规格工程师（`agent-spec`） |
| 影响范围不清、重构、跨模块 | 系统架构师（`agent-architect`） |
| 数据库变更 | 产品规格工程师 -> 数据库工程师（`agent-dba`）-> 开发工程师 |
| 后端/前端/UI 实现、CRUD 脚手架 | 开发工程师（`agent-dev`），按栈读对应章节和 rules |
| 测试用例设计、测试执行 | 测试工程师（`agent-test`） |
| 安全/性能风险、发布前审查 | 发布审查工程师（`agent-release`） |

## 标准流程

### 新功能

```text
产品规格工程师（agent-spec）需求澄清 + OpenSpec + API 契约（如涉及接口）
-> 系统架构师（agent-architect），如代码区域陌生或影响范围不清
-> 数据库工程师（agent-dba），如涉及数据库
-> 测试工程师（agent-test）设计验收测试用例（test-cases.md），随 OpenSpec 一起等待用户确认
-> 开发工程师（agent-dev）实现（含 UI/前端/后端/CRUD 脚手架，按栈读对应章节）
-> 测试工程师（agent-test）按已确认用例执行并回填状态
-> 发布审查工程师（agent-release），含安全/性能必查项
```

### Bug 修复

```text
诊断和复现
-> 系统架构师（agent-architect），如调用链不清
-> 产品规格工程师（agent-spec），如业务规则或接口契约不清
-> 数据库工程师（agent-dba），如涉及 SQL、数据或表结构
-> 开发工程师（agent-dev）修复
-> 测试工程师（agent-test）
-> 发布审查工程师（agent-release）
```

### 数据库变更

```text
产品规格工程师（agent-spec）
-> 数据库工程师（agent-dba）：表结构设计审查 -> 数据库变更确认包（两阶段确认）
-> 产品规格工程师（agent-spec），如影响接口契约
-> 测试工程师（agent-test）设计验收测试用例，随 OpenSpec 一起等待用户确认
-> 开发工程师（agent-dev）
-> 测试工程师（agent-test）按已确认用例执行并回填状态
-> 发布审查工程师（agent-release）
```

强制点：

- 必须列出表、字段、索引、forward SQL、rollback SQL、历史数据影响。
- 执行数据库写操作前必须获得用户确认。

### API 变更

```text
产品规格工程师（agent-spec）：需求 + API 契约
-> 数据库工程师（agent-dba），如涉及字段或 SQL
-> 开发工程师（agent-dev）：后端实现 + 前端联动（如影响前端）
-> 测试工程师（agent-test）
-> 发布审查工程师（agent-release）
```

强制点：

- 必须明确路径、方法、请求、响应、错误、分页、鉴权、兼容性和敏感字段。

### 前端/设计变更

```text
产品规格工程师（agent-spec）
-> 开发工程师（agent-dev）：UI 设计 + 前端实现（读 04-ux/05-ui-design/30-frontend 及对应栈规则）
-> 测试工程师（agent-test）
-> 发布审查工程师（agent-release）
```

强制点：

- 必须覆盖入口、主路径、加载态、空态、错误态、权限态、表单校验和高风险确认。

### 解耦/重构

```text
系统架构师（agent-architect）
-> 产品规格工程师（agent-spec），如涉及行为或模块边界变化
-> 测试工程师（agent-test）
-> 分批最小实现
-> 发布审查工程师（agent-release）
```

强制点：

- 重构必须有切片和回退路径。
- 不允许借重构改变未确认业务行为。
- 每个切片都要能独立验证。

### 独立二审

```text
实现完成
-> .ai-control/control/scripts/run-tests.sh
-> .ai-control/control/scripts/prepare-review.sh，如涉及复杂业务、DB、权限、状态流或发布风险
-> .ai-control/control/scripts/run-review.sh
-> 发布审查工程师（agent-release）
```

强制点：

- 独立二审只做审查，不能替代 OpenSpec 或用户确认。
- 独立二审意见必须由 AI 助手判断是否成立，不能自动当作已确认业务规则。

## 冲突处理

优先级为全序，同时触发时按此顺序：

1. 产品规格工程师（`agent-spec`）：规格和契约未确认时，先于一切实现。
2. 系统架构师（`agent-architect`）：影响范围不清时，先于实现。
3. 数据库工程师（`agent-dba`）：涉及表结构时，先于后端实现。
4. 开发工程师（`agent-dev`）：实现执行者；CRUD 脚手架未确认 adapter 时禁止生成，generic adapter 只允许生成审查预览包，真实落地必须经用户确认。
5. 测试工程师（`agent-test`）：设计期先于实现介入（写用例），执行期在实现之后。
6. 发布审查工程师（`agent-release`）：只做最终审查，不代替实现。
