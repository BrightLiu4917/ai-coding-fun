# 控制系统规格

## 功能模块

- 仓库入口：根目录 `AGENTS.md` 作为 AI 编码工具（Codex/Kimi/Cursor 等）自动发现入口，根目录 `README.md` 作为人工阅读入口。
- 仓库资产：控制系统仓库自身的主要资产统一维护在 `control/` 目录。
- 项目接入：通过交互式或非交互式脚本把控制系统复制到目标项目。
- 目标项目新安装：根目录保留 `AGENTS.md`、`openspec/`、`CONTEXT.md` 和 `CONTEXT-MAP.md`，控制系统工具资产安装到 `.ai-control/control/`。
- 项目画像：识别目标项目技术栈，生成 `.ai-control/project.env` 和 `.ai-control/project-profile.md`。
- 规则分层：通用规则、技术栈规则和功能规则分目录维护。
- Agent 路由：使用 `agents/agent-*.md` 作为中文角色手册。
- OpenSpec：使用中文 proposal、design、tasks 和 spec 记录事实源。
- 独立二审：通过 `.agent/review.env` 和 review 脚本执行独立审查。

## 数据结构

- `control/AGENTS.md`：安装到目标业务项目的 `AGENTS.md` 模板。
- `control/CONTEXT.md`：安装到目标业务项目的上下文模板。
- `control/CONTEXT-MAP.md`：安装到目标业务项目的上下文地图模板。
- `control/openspec/`：控制系统仓库自身的 OpenSpec 事实源。
- `control/agents/`：控制系统仓库自身维护的中文角色手册。
- `control/docs/`：控制系统仓库自身维护的工程规则和审查标准。
- `control/scripts/`：控制系统仓库自身维护的安装、检测、检查、测试和二审脚本。
- `control/templates/`：控制系统仓库自身维护的标准产物模板。
- `control/profiles/`：控制系统仓库自身维护的安装 profile。
- `control/tools/`：控制系统仓库自身维护的确定性工具。
- `control/examples/`：控制系统仓库自身维护的示例项目。
- `.ai-control/project.env`：项目画像，不包含密钥。
- `.ai-control/control/`：目标业务项目中新安装的控制系统工具资产目录。
- `.ai-control/control/agents/`：目标业务项目中的中文角色手册。
- `.ai-control/control/docs/`：目标业务项目中的工程规则和审查标准。
- `.ai-control/control/scripts/`：目标业务项目中的安装、检测、检查、测试和二审脚本。
- `.ai-control/control/templates/`：目标业务项目中的标准产物模板。
- `.ai-control/control/profiles/`：目标业务项目中的安装 profile。
- `.ai-control/control/tools/`：目标业务项目中的确定性工具。
- `.agent/project.env`：本机覆盖配置，不提交。
- `.agent/review.env`：独立二审 密钥配置，不提交。
- `profiles/<name>/profile.toml`：安装文件清单。
- `openspec/changes/<change-id>/`：变更记录。
- `openspec/specs/<capability>/spec.md`：已确认规格。

## 权限设计

本项目自身没有运行时用户权限。复制到目标业务项目后，后台功能必须先确认访问控制模式：本服务建设 RBAC、外部权限服务/网关/IAM/SSO 负责，或当前功能明确不适用。

如果本服务建设 RBAC，必须确认菜单权限、按钮权限、接口权限和数据范围。如果外部系统负责，必须确认责任系统、凭证传递、失败处理和越权处理。

## 异常处理

- 安装脚本遇到路径冲突时必须停止，除非用户显式使用 `--backup` 或 `--force`。
- 目标项目新安装默认使用 `.ai-control/control/` 存放工具资产。
- 已安装旧结构的目标项目不在本规则中自动迁移。
- 缺少目标目录时，交互式安装可以询问是否创建；非交互脚本可以创建。
- 独立二审 配置缺失时只提示，不阻塞本地规则使用。

## 数据校验规则

- profile 条目必须是仓库内相对路径，禁止绝对路径和 `..`。
- OpenSpec 文档默认执行中文检查。
- 后台功能检查必须覆盖访问控制方案；本服务建设 RBAC 时才强制检查本地权限码。
- SQL 文件检查必须禁止明显危险语句。
- 数据库变更必须先输出表结构设计审查并等待用户确认；确认后才允许输出数据库变更确认包，确认包包含目标结构 DDL、本地手动执行 DDL、rollback SQL、联动改动清单、Laravel / Hyperf migration 文件预览（如适用）、建议和待确认项；用户确认确认包前禁止执行 SQL、写入 migration 文件或实现依赖新表结构的代码。

## 日志说明

- 测试日志写入 `.agent/logs/`。
- 独立二审 输入输出写入 `.agent/reviews/`。
- `.agent/` 默认忽略，避免密钥和运行产物误提交。
