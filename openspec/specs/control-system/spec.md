# 控制系统规格

## 功能模块

- 项目接入：通过交互式或非交互式脚本把控制系统复制到目标项目。
- 项目画像：识别目标项目技术栈，生成 `.ai-control/project.env` 和 `.ai-control/project-profile.md`。
- 规则分层：通用规则、技术栈规则和功能规则分目录维护。
- Agent 路由：使用 `agents/agent-*.md` 作为中文角色手册。
- OpenSpec：使用中文 proposal、design、tasks 和 spec 记录事实源。
- deepv4 二审：通过 `.agent/deepv4.env` 和 review 脚本执行独立审查。

## 数据结构

- `.ai-control/project.env`：项目画像，不包含密钥。
- `.agent/project.env`：本机覆盖配置，不提交。
- `.agent/deepv4.env`：deepv4 密钥配置，不提交。
- `profiles/<name>/profile.toml`：安装文件清单。
- `openspec/changes/<change-id>/`：变更记录。
- `openspec/specs/<capability>/spec.md`：已确认规格。

## 权限设计

本项目自身没有运行时用户权限。复制到目标业务项目后，后台功能必须先确认访问控制模式：本服务建设 RBAC、外部权限服务/网关/IAM/SSO 负责，或当前功能明确不适用。

如果本服务建设 RBAC，必须确认菜单权限、按钮权限、接口权限和数据范围。如果外部系统负责，必须确认责任系统、凭证传递、失败处理和越权处理。

## 异常处理

- 安装脚本遇到路径冲突时必须停止，除非用户显式使用 `--backup` 或 `--force`。
- 缺少目标目录时，交互式安装可以询问是否创建；非交互脚本可以创建。
- deepv4 配置缺失时只提示，不阻塞本地规则使用。

## 数据校验规则

- profile 条目必须是仓库内相对路径，禁止绝对路径和 `..`。
- OpenSpec 文档默认执行中文检查。
- 后台功能检查必须覆盖访问控制方案；本服务建设 RBAC 时才强制检查本地权限码。
- SQL 文件检查必须禁止明显危险语句。

## 日志说明

- 测试日志写入 `.agent/logs/`。
- deepv4 输入输出写入 `.agent/reviews/`。
- `.agent/` 默认忽略，避免密钥和运行产物误提交。
