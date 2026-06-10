# 控制系统规格变更

## 功能模块

- 系统必须支持将安装到目标业务项目的控制系统工具资产统一放入目标控制目录。
- 系统必须保留目标业务项目根目录 `AGENTS.md` 作为 Codex 自动发现入口。
- 系统应该保留目标业务项目根目录 `openspec/`、`CONTEXT.md` 和 `CONTEXT-MAP.md` 作为业务事实源，除非用户另行确认。

## 业务流程

- 前置条件：用户已确认目标控制目录名称、OpenSpec 位置和旧结构兼容策略。
- 当用户执行新安装时，系统必须把 agent、docs、scripts、templates、profiles 和 tools 安装到目标控制目录。
- 当 Codex 读取目标项目根目录 `AGENTS.md` 时，系统必须能定位目标控制目录下的规则、agent 和脚本。
- 当安装脚本发现目标项目已有旧结构控制资产时，系统不得自动迁移；本变更只面向新用户和新安装。

## 状态流转

- 本变更不涉及运行时业务状态。
- 任务状态必须使用“待处理”“进行中”“已完成”。

## 数据结构

- `.ai-control/project.env`：目标项目画像。
- `.ai-control/project-profile.md`：目标项目画像说明。
- `.ai-control/control/`：推荐的目标项目控制系统工具资产目录。
- `.ai-control/control/agents/`：目标项目 agent 手册。
- `.ai-control/control/docs/`：目标项目工程规则。
- `.ai-control/control/scripts/`：目标项目控制系统脚本。
- `.ai-control/control/templates/`：目标项目模板。
- `.ai-control/control/profiles/`：目标项目安装 profile，如安装。
- `.ai-control/control/tools/`：目标项目确定性工具。
- `AGENTS.md`：目标项目根目录入口。
- `openspec/`：目标项目业务事实源，默认保留根目录。
- `CONTEXT.md` / `CONTEXT-MAP.md`：目标项目上下文，默认保留根目录。

## 接口设计

- 本变更不涉及运行时 API。
- 目标项目命令路径必须更新为 `.ai-control/control/scripts/<script-name>.sh`。

## 权限设计

- 本变更不涉及运行时权限。
- `.agent/` 必须继续作为本机密钥和运行产物目录，默认不提交。

## 异常处理

- 安装脚本遇到旧结构控制资产时，必须停止并提示，不得静默迁移。
- 安装脚本遇到新目标路径冲突时，必须遵守 `--backup`、`--force` 和 `--dry-run` 语义。
- 目标项目检查脚本无法定位根目录时，必须输出明确错误。

## 边界情况处理

- 已安装旧结构的目标项目不在本变更中自动迁移，本变更只处理新安装输出结构。
- 如果用户只安装 `--only` 单个文件，系统必须保持目标路径映射一致。
- 如果目标项目已经存在 `.ai-control/project.env`，安装脚本不得静默覆盖。

## 数据校验规则

- profile 条目必须继续禁止绝对路径和 `..`。
- 安装 dry-run 必须显示最终目标路径。
- 文档链接检查必须能识别目标控制目录下的规则路径。

## 日志说明

- 测试日志继续写入目标项目 `.agent/logs/`。
- deepv4 输入输出继续写入目标项目 `.agent/reviews/`。
- `.ai-control/control/` 不得存放密钥或 review 输出。

## 待确认问题

### 问题 1：目标控制目录
- 需要确认：已确认使用 `.ai-control/control/` 作为目标项目控制系统工具资产目录。
- 建议方案：使用 `.ai-control/control/`。
- 推荐原因：保留 `.ai-control/` 项目画像语义，同时用 `control/` 子目录隔离工具资产。
- 影响范围：安装脚本、profile、目标项目入口模板和命令说明。
- 可选方案：使用 `.ai-control/` 直接存放，或使用根目录 `control/`。
- 默认处理：已确认，按 `.ai-control/control/` 进入实现。

### 问题 2：业务事实源位置
- 需要确认：已确认目标项目 `openspec/`、`CONTEXT.md` 和 `CONTEXT-MAP.md` 保留根目录。
- 建议方案：保留根目录。
- 推荐原因：它们是业务事实源，不只是控制系统工具资产。
- 影响范围：Codex 入口、OpenSpec 检查、用户工作流和文档路径。
- 可选方案：一并迁入 `.ai-control/control/`。
- 默认处理：已确认，按保留根目录进入实现。
