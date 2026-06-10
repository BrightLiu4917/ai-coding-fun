# 控制系统规格变更

## 功能模块

- 系统必须支持将控制系统仓库自身的主要资产统一维护在 `control/` 目录。
- 系统必须保留根目录 `AGENTS.md` 作为 Codex 自动发现入口。
- 系统应该保留根目录 `README.md` 作为人工阅读入口。
- 系统必须在根目录入口中明确指向 `control/openspec/`、`control/agents/`、`control/docs/`、`control/scripts/`、`control/templates/`、`control/profiles/`、`control/tools/` 和 `control/examples/`。

## 业务流程

- 前置条件：用户已确认目录名称、根目录保留文件和目标业务项目安装输出是否同步调整。
- 当控制系统仓库执行结构迁移时，系统必须先移动控制系统资产，再同步更新所有路径引用。
- 当 Codex 读取根目录 `AGENTS.md` 时，系统必须能定位到 `control/` 下的事实源、规则文档和 agent 手册。
- 当用户运行检查脚本时，系统必须能通过新路径执行检查。

## 状态流转

- 本变更不涉及运行时业务状态。
- 迁移任务状态必须使用“待处理”“进行中”“已完成”。

## 数据结构

- `control/`：控制系统仓库自身的资产根目录。
- `control/openspec/`：控制系统规格和变更事实源。
- `control/agents/`：中文角色手册。
- `control/docs/`：工程规则和审查标准。
- `control/scripts/`：安装、检测、检查、测试和二审脚本。
- `control/templates/`：标准产物模板。
- `control/profiles/`：安装 profile。
- `control/tools/`：确定性工具。
- `control/examples/`：示例项目。

## 接口设计

- 本变更不涉及运行时 API。
- Shell 命令入口必须在文档中使用迁移后的路径，例如 `bash control/scripts/check-project-ready.sh`。

## 权限设计

- 本变更不涉及运行时权限。
- `.agent/` 必须继续作为本机配置和运行产物目录，默认不提交。

## 异常处理

- 如果脚本无法定位 `control/`，必须输出明确错误并停止。
- 如果检查脚本发现旧路径引用或断链，必须失败或输出明确警告。

## 边界情况处理

- 已安装到目标业务项目的旧结构不在本变更中自动迁移。
- 根目录 `.git/`、`.gitignore`、`.agent/`、`.idea/` 等版本管理、本机配置或 IDE 文件不迁入 `control/`。
- 如果路径文本是说明旧结构的历史记录，允许保留，但必须在发布审查中说明。

## 数据校验规则

- profile 条目必须继续禁止绝对路径和 `..`。
- 文档链接检查必须覆盖 `control/` 下的 Markdown 文件。
- OpenSpec 中文检查必须覆盖 `control/openspec/`。

## 日志说明

- 测试日志继续写入 `.agent/logs/`。
- deepv4 输入输出继续写入 `.agent/reviews/`。
- 迁移过程不得把密钥、日志或 review 产物移动到 `control/`。

## 待确认问题

### 问题 1：目录名称
- 需要确认：是否使用 `control/` 作为控制系统仓库自身的资产目录。
- 建议方案：使用 `control/`。
- 推荐原因：语义清晰，并与目标业务项目的 `.ai-control/` 项目画像目录区分。
- 影响范围：影响全部路径引用、脚本和 README。
- 可选方案：使用 `.control/`、`ai-control/` 或 `.ai-control-system/`。
- 默认处理：如用户确认，才按 `control/` 进入实现；未确认前不得移动文件。

### 问题 2：安装输出是否同步调整
- 需要确认：本次是否同步调整安装到目标业务项目后的输出结构。
- 建议方案：本次不同步调整，只处理控制系统仓库自身结构。
- 推荐原因：降低结构迁移回归风险，目标项目安装结构可后续独立设计。
- 影响范围：影响安装脚本、profile 和用户接入文档。
- 可选方案：本次同步调整目标业务项目安装结构。
- 默认处理：如用户确认，才按建议方案进入实现；未确认前不得修改安装输出语义。
