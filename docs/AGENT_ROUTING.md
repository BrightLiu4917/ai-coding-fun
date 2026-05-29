# Agent 路由规则

## 目标

让 Codex 按少量、清晰的工程角色工作。所有 agent 都放在根目录 `agents/`，使用普通 Markdown 文件，不再依赖隐藏目录。

## Agent 清单

对用户输出时优先使用中文角色名；需要定位文件、路由或脚本校验时，再保留 agent id。

```text
agents/agent-product.md      # 产品需求工程师：产品、业务目标、领域建模
agents/agent-openspec.md     # OpenSpec 规格工程师：OpenSpec 提案、执行、归档
agents/agent-architect.md    # 系统架构师：架构、影响范围、重构切片
agents/agent-ui.md           # UI 交互设计师：UX/UI、交互、视觉状态
agents/agent-web.md          # Web 前端开发工程师：Vue/React 前端实现和前端测试
agents/agent-api.md          # API 契约工程师：API 契约
agents/agent-java.md         # Java 后端开发工程师：Spring Boot 后端实现
agents/agent-go.md           # Go 后端开发工程师：Go / Gin 后端实现
agents/agent-php.md          # PHP 后端开发工程师：PHP 后端实现
agents/agent-dba.md          # 数据库工程师：MySQL 表结构、SQL、迁移、回滚
agents/agent-codegen.md      # 代码生成工程师：CRUD 脚手架和 adapter 判断
agents/agent-test.md         # 测试工程师：单测、集成测试、E2E、验收
agents/agent-security.md     # 安全工程师：安全审查
agents/agent-performance.md  # 性能工程师：性能审查
agents/agent-release.md      # 发布审查工程师：deepv4 二审、上线前审查
```

## 快速分类

| 任务类型 | 必须读取 |
|----------|----------|
| 新功能 | 产品需求工程师（`agent-product`）-> OpenSpec 规格工程师（`agent-openspec`）-> 按影响范围读取其他 agent |
| 业务规则不清 | 产品需求工程师（`agent-product`） |
| OpenSpec 创建/执行/归档 | OpenSpec 规格工程师（`agent-openspec`） |
| 影响范围不清、重构、跨模块 | 系统架构师（`agent-architect`） |
| 数据库变更 | OpenSpec 规格工程师（`agent-openspec`）-> 数据库工程师（`agent-dba`）-> API 契约工程师/对应后端开发工程师（`agent-api`/`agent-java`/`agent-go`/`agent-php`） |
| API 变更 | OpenSpec 规格工程师（`agent-openspec`）-> API 契约工程师（`agent-api`）-> 对应后端开发工程师/Web 前端开发工程师（`agent-java`/`agent-go`/`agent-php`/`agent-web`） |
| 后端实现 | 按技术栈读取 Java/Go/PHP 后端开发工程师（`agent-java`/`agent-go`/`agent-php`） |
| 前端实现 | UI 交互设计师（`agent-ui`）-> Web 前端开发工程师（`agent-web`） |
| CRUD 生成 | 代码生成工程师（`agent-codegen`），必要时再转 Java 后端开发工程师（`agent-java`） |
| 测试 | 测试工程师（`agent-test`） |
| 安全风险 | 安全工程师（`agent-security`） |
| 性能风险 | 性能工程师（`agent-performance`） |
| 发布前审查 | 发布审查工程师（`agent-release`） |

## 标准流程

### 新功能

```text
产品需求工程师（agent-product）
-> OpenSpec 规格工程师（agent-openspec）
-> 系统架构师（agent-architect），如代码区域陌生或影响范围不清
-> UI 交互设计师（agent-ui），如涉及页面或交互
-> API 契约工程师（agent-api），如涉及接口
-> 数据库工程师（agent-dba），如涉及数据库
-> 代码生成工程师（agent-codegen），如涉及标准 CRUD 脚手架
-> Java/Go/PHP 后端开发工程师 / Web 前端开发工程师（agent-java / agent-go / agent-php / agent-web）
-> 测试工程师（agent-test）
-> 安全工程师 / 性能工程师（agent-security / agent-performance），如有风险
-> 发布审查工程师（agent-release）
```

### Bug 修复

```text
诊断和复现
-> 系统架构师（agent-architect），如调用链不清
-> 产品需求工程师（agent-product），如业务规则不清
-> 数据库工程师（agent-dba），如涉及 SQL、数据或表结构
-> API 契约工程师（agent-api），如涉及接口契约
-> Java/Go/PHP 后端开发工程师 / Web 前端开发工程师（agent-java / agent-go / agent-php / agent-web）
-> 测试工程师（agent-test）
-> 发布审查工程师（agent-release）
```

### 数据库变更

```text
OpenSpec 规格工程师（agent-openspec）
-> 数据库工程师（agent-dba）
-> API 契约工程师（agent-api），如影响接口
-> 对应后端开发工程师（agent-java / agent-go / agent-php）
-> 测试工程师（agent-test）
-> 发布审查工程师（agent-release）
```

强制点：

- 必须列出表、字段、索引、forward SQL、rollback SQL、历史数据影响。
- 执行数据库写操作前必须获得用户确认。

### API 变更

```text
OpenSpec 规格工程师（agent-openspec）
-> API 契约工程师（agent-api）
-> 数据库工程师（agent-dba），如涉及字段或 SQL
-> 对应后端开发工程师（agent-java / agent-go / agent-php）
-> Web 前端开发工程师（agent-web），如影响前端
-> 测试工程师（agent-test）
-> 发布审查工程师（agent-release）
```

强制点：

- 必须明确路径、方法、请求、响应、错误、分页、鉴权、兼容性和敏感字段。

### 前端/设计变更

```text
OpenSpec 规格工程师（agent-openspec）
-> UI 交互设计师（agent-ui）
-> API 契约工程师（agent-api），如涉及接口
-> Web 前端开发工程师（agent-web）
-> 测试工程师（agent-test）
-> 发布审查工程师（agent-release）
```

强制点：

- 必须覆盖入口、主路径、加载态、空态、错误态、权限态、表单校验和高风险确认。

### 解耦/重构

```text
系统架构师（agent-architect）
-> OpenSpec 规格工程师（agent-openspec），如涉及行为或模块边界变化
-> 测试工程师（agent-test）
-> 分批最小实现
-> 发布审查工程师（agent-release）
```

强制点：

- 重构必须有切片和回退路径。
- 不允许借重构改变未确认业务行为。
- 每个切片都要能独立验证。

### deepv4 二审

```text
实现完成
-> scripts/run-tests.sh
-> scripts/prepare-deepv4-review.sh，如涉及复杂业务、DB、权限、状态流或发布风险
-> scripts/run-deepv4-review.sh
-> 发布审查工程师（agent-release）
```

强制点：

- deepv4 只做二审，不能替代 OpenSpec 或用户确认。
- deepv4 意见必须由 Codex 判断是否成立，不能自动当作已确认业务规则。

## 冲突处理

- 数据库工程师（`agent-dba`）与后端实现同时触发时，先数据库工程师。
- API 契约工程师（`agent-api`）与后端/前端实现同时触发时，先 API 契约工程师。
- 代码生成工程师（`agent-codegen`）与 Java 后端开发工程师（`agent-java`）冲突时，先代码生成工程师判断 adapter。
- CRUD 生成未确认 adapter 时禁止生成。
- generic adapter 只允许生成审查预览包；真实落地必须经用户确认后转入 Java 后端开发工程师（`agent-java`）。
- 系统架构师（`agent-architect`）与实现型 agent 冲突时，先系统架构师。
- OpenSpec 规格工程师（`agent-openspec`）与任何实现型 agent 冲突时，先 OpenSpec 规格工程师。
- 发布审查工程师（`agent-release`）只做最终审查，不代替实现。
