# 变更提案：控制系统仓库目录收敛

## 项目背景

当前控制系统仓库根目录直接展开 `agents/`、`docs/`、`scripts/`、`templates/`、`profiles/`、`tools/`、`examples/`、`openspec/` 和上下文文件。该结构便于早期开发，但随着控制系统资产增多，根目录信息密度变高，用户反馈希望除核心入口外的项目文件统一放到一个目录下管理。

## 项目目标

- 将控制系统仓库自身的主要资产收敛到 `control/` 目录。
- 保留根目录 `AGENTS.md` 作为 Codex 自动发现和全局契约入口。
- 保留根目录 `README.md` 作为人工阅读入口。
- 更新所有路径引用、脚本根路径、profile 清单、文档链接和 OpenSpec 说明。
- 保证控制系统安装到目标业务项目的行为可验证、可回滚。

## 核心问题

- 根目录文件过多，控制系统资产和仓库入口混在一起。
- 如果直接移动目录但不修正脚本和文档引用，会导致安装、检查、OpenSpec 路由和示例失效。
- 本仓库结构和安装到业务项目后的结构需要明确区分，避免把仓库本体调整误当成目标项目安装规则。

## 功能范围

- 范围内：新增 `control/` 作为控制系统资产目录。
- 范围内：迁移 `CONTEXT.md`、`CONTEXT-MAP.md`、`CODEX_TASK_TEMPLATE.md`、`openspec/`、`agents/`、`docs/`、`scripts/`、`templates/`、`profiles/`、`tools/` 和 `examples/`。
- 范围内：更新根目录 `AGENTS.md`，让其指向 `control/` 下的事实源和规则文件。
- 范围内：更新 `README.md`、脚本、profile、模板、示例和 OpenSpec 文档中的路径引用。
- 范围内：补充验证脚本，确保目录迁移后链接、agent、OpenSpec 和安装检查仍可运行。

## 核心价值

- 根目录更清晰，保留给仓库入口和通用项目文件。
- 控制系统资产集中管理，后续做安装输出、skill 提取或版本打包更容易。
- 降低新用户第一次打开仓库时的目录认知成本。

## 变更内容

- 新增：`control/` 目录。
- 修改：根目录入口文档和所有相对路径引用。
- 修改：脚本中的仓库根目录、控制系统资产目录和目标项目目录计算逻辑。
- 修改：profile 安装清单和相关检查脚本。
- 废弃：根目录直接承载多数控制系统资产的结构。

## 非目标

- 不修改业务规则、数据库规则、API 规则或 agent 职责内容。
- 不修改目标业务项目的运行时代码。
- 不调整数据库、接口、权限、页面或状态流转。
- 不引入新依赖。
- 不自动改变已安装到其他业务项目中的目录结构。

## 影响

- 产品/业务：改善控制系统仓库自身可读性，不改变业务规则。
- 交互和界面：不涉及页面交互。
- 前端：不涉及前端代码。
- 接口：不涉及运行时 API。
- 后端：不涉及后端运行时代码。
- 数据库：不涉及数据库。
- 测试：需要更新并执行文档链接、agent、OpenSpec、路由和安装 dry-run 检查。
- 发布：属于仓库结构重构，发布前必须审查路径引用和脚本兼容性。

## 影响范围

```yaml
affected_files:
  - AGENTS.md
  - README.md
  - CONTEXT.md
  - CONTEXT-MAP.md
  - CODEX_TASK_TEMPLATE.md
  - openspec
  - agents
  - docs
  - scripts
  - templates
  - profiles
  - tools
  - examples
affected_tables:
  - none
affected_apis:
  - none
affected_pages:
  - none
affected_agents:
  - agent-openspec
  - agent-architect
  - agent-release
```

## 风险说明

- 脚本路径大量依赖当前根目录结构，迁移后如果漏改会导致安装、检测或检查脚本失败。
- OpenSpec、agent 和 docs 中存在大量相对路径引用，漏改会影响 Codex 路由和人工阅读。
- 目标业务项目安装输出结构是否同步调整需要用户确认，否则可能产生“仓库本体结构”和“安装输出结构”不一致的理解成本。
- 文件移动会造成较大的 git diff，需要避免夹带规则内容改动。

## 待确认问题

### 问题 1：控制系统资产目录名称
- 需要确认：是否确认使用 `control/` 作为仓库本体的控制系统资产目录。
- 建议方案：使用 `control/`。
- 推荐原因：`control/` 适合作为本仓库产品源码目录；`.ai-control/` 更适合安装到目标业务项目后的项目画像目录，避免语义混淆。
- 影响范围：影响所有文档路径、脚本路径和 README 目录说明。
- 可选方案：使用 `.control/`、`ai-control/` 或 `.ai-control-system/`。
- 默认处理：如用户确认，才按 `control/` 进入实现；未确认前不得移动文件。

### 问题 2：根目录保留文件
- 需要确认：根目录是否只保留 `AGENTS.md`、`README.md`、`.gitignore`、`.git/`、`.agent/`、`.idea/` 等入口、版本管理、本机或 IDE 文件。
- 建议方案：根目录保留 `AGENTS.md` 和 `README.md`，其他控制系统资产迁入 `control/`。
- 推荐原因：`AGENTS.md` 是 Codex 自动发现入口，`README.md` 是人工入口；其他资产集中后根目录更清爽。
- 影响范围：影响 Codex 入口、人工阅读入口和目录结构。
- 可选方案：仅保留 `AGENTS.md`，连 `README.md` 也迁入 `control/`。
- 默认处理：如用户确认，才按建议方案进入实现；未确认前不得移动文件。

### 问题 3：目标业务项目安装输出结构
- 需要确认：本次是否同步调整安装到业务项目后的输出结构。
- 建议方案：本次先只调整本仓库结构，安装输出结构保持现状，待迁移稳定后另开 change 处理目标项目安装结构。
- 推荐原因：仓库本体迁移已经涉及大量路径，分开处理可以降低回归风险。
- 影响范围：影响 `scripts/install-to-project.sh`、`scripts/bootstrap-new-project.sh` 和 `profiles/` 的后续设计。
- 可选方案：本次同步调整目标业务项目安装结构为根目录轻入口加 `.ai-control/` 统一管理。
- 默认处理：如用户确认，才按建议方案进入实现；未确认前不得修改安装输出语义。
