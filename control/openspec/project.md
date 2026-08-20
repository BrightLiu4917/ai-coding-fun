# AI 全栈控制系统

## 项目定位
本项目是一套可复制到业务项目根目录的 AI 开发控制系统。

它不提供业务运行时，不替代后端、前端、数据库或 CI/CD 框架。它的职责是把 AI 助手、OpenSpec、中文 agent、规则文档、检查脚本、独立二审和脚手架预览能力组织成可确认、可审查、可验证的工程流程。

复制到具体业务项目后，目标项目的 `openspec/project.md` 应由 `.ai-control/control/scripts/init-project.sh` 重新生成或手工补充。

## 技术栈
- Bash 脚本。
- Markdown 文档。
- OpenSpec 风格需求、设计、任务和规格文件。
- 可选独立二审 OpenAI-compatible API。
- 可选 Java Spring Boot CRUD 预览脚手架。
- 可选 GitHub Actions / GitLab CI 模板。

## 领域语言
- 控制系统：复制到目标项目的 AI 工程规则集合。
- OpenSpec：需求、设计、任务、规格和归档事实源。
- Agent：位于 `agents/` 下的中文角色手册。
- Profile：控制安装范围的文件清单。
- 项目画像：`.ai-control/project.env` 和 `.ai-control/project-profile.md`。
- 本机配置：`.agent/` 下的密钥、日志、review 输入输出和测试覆盖配置。
- 独立二审：对 diff、测试结果和风险点做独立审查。

## 范围
包含：
- 项目接入和 profile 安装。
- 项目技术栈识别和项目画像生成。
- 中文 OpenSpec 输出规则。
- 角色化 agent 手册。
- API、DB、后端、前端、安全、性能、测试和发布规则。
- 检查脚本、测试入口、独立二审入口。
- 通用 CRUD 预览脚手架。

不包含：
- 业务运行时代码。
- 数据库服务、Redis 服务或 Docker 环境安装。
- 自动替用户决定字段、状态、权限、响应格式或业务流程。
- 自动执行生产数据库写操作。

## 治理规则
- 非简单任务必须先创建 `openspec/changes/<change-id>/`。
- OpenSpec 文档必须遵守 `openspec/config.yaml` 的中文输出和结构规则。
- 已确认业务规则必须沉淀到 `openspec/specs/<capability>/spec.md`。
- 设计决策和风险必须记录到 `design.md`。
- 实施任务必须记录到 `tasks.md`。
- 实现完成后必须归档已确认规格。
- 控制系统自身的重大脚本、profile、agent 和规则变更，也应保留 OpenSpec change 记录作为示例。
- `.agent/` 是本机配置和运行产物，默认不提交。
- `.ai-control/` 是项目画像，目标项目可以提交，且不能存放密钥。
