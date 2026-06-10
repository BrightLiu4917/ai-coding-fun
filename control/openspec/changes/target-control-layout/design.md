# 设计说明：目标项目安装输出目录收敛

## 系统架构

推荐目标业务项目安装后结构：

```text
目标项目根目录/
├── AGENTS.md
├── CONTEXT.md
├── CONTEXT-MAP.md
├── openspec/
├── .ai-control/
│   ├── project.env
│   ├── project-profile.md
│   └── control/
│       ├── agents/
│       ├── docs/
│       ├── scripts/
│       ├── templates/
│       ├── profiles/
│       └── tools/
└── .agent/
```

根目录 `AGENTS.md` 是入口，必须指向 `.ai-control/control/agents/`、`.ai-control/control/docs/` 和 `.ai-control/control/scripts/`。`openspec/`、`CONTEXT.md`、`CONTEXT-MAP.md` 暂时保留根目录，作为业务事实源。

## 模块设计

- 安装脚本：负责把源文件从仓库 `control/` 复制到目标项目新路径。
- profile：继续描述要安装的逻辑条目，但安装脚本需要支持目标路径映射。
- 目标项目入口模板：`control/AGENTS.md` 需要改为指向 `.ai-control/control/`。
- 检查脚本：安装到目标项目后，应能从 `.ai-control/control/scripts/` 定位目标项目根目录和控制资产目录。
- 项目画像：`.ai-control/project.env` 和 `.ai-control/project-profile.md` 保持在 `.ai-control/` 下。

## 流程设计

```text
用户执行安装脚本
-> 检查目标项目是否已有旧结构控制资产
-> 生成或更新 .ai-control/project.env
-> 复制根目录 AGENTS.md、CONTEXT.md、CONTEXT-MAP.md 和 openspec/
-> 复制工具资产到 .ai-control/control/
-> 运行目标项目检查脚本
-> 输出新命令路径和下一步提示
```

## 产品和交互

- 用户流程：用户仍从根目录 `AGENTS.md` 开始，不需要记住隐藏目录。
- 状态设计：不涉及运行时状态。
- 异常流程：检测到旧结构时停止并提示，不自动覆盖。

## 接口设计

- 路径：不涉及运行时 API。
- 请求：不涉及运行时请求。
- 响应：不涉及运行时响应。
- 兼容性：目标项目命令从 `bash scripts/ai-dev.sh` 变为 `bash .ai-control/control/scripts/ai-dev.sh`。

## 数据库设计

- 表：不涉及。
- 字段：不涉及。
- 索引：不涉及。
- 迁移：不涉及。
- 回滚：不涉及。

## 技术选型

- 继续使用 Bash。
- 不引入路径映射依赖。
- 安装脚本内部维护逻辑条目到目标路径的映射。

## 性能设计

本变更不涉及运行时性能。安装和检查仍使用 Bash、find、rg 等轻量工具。

## 扩展性设计

- 后续可以增加显式迁移命令，例如 `--migrate-layout`。
- 后续可以支持 profile 直接声明目标路径，但本次不引入新的 profile schema，避免过大改动。

## 安全设计

- `.agent/` 继续存放密钥、日志和 deepv4 产物，默认不提交。
- `.ai-control/project.env` 不得存放密钥。
- `.ai-control/control/` 不得存放密钥、token、private key 或生产连接串。

## 访问控制

- 访问控制模式：不适用。
- 本服务是否建设 RBAC：不适用。
- 责任系统：不涉及。
- 允许主体或角色：不涉及。
- 权限码或权限点：不涉及。
- 菜单权限，如适用：不涉及。
- 按钮权限，如适用：不涉及。
- 无权限处理：不涉及。
- 越权处理：不涉及。
- 数据范围：不涉及。

## 验证方案

- 运行 shell 语法检查。
- 运行控制系统仓库自身 agent、文档链接、路由和 OpenSpec 检查。
- 使用临时目录执行安装 dry-run，确认输出路径。
- 使用临时目录执行真实安装，确认根目录和 `.ai-control/control/` 结构。
- 在临时目标项目中运行 `.ai-control/control/scripts/check-project-ready.sh`。
- 验证 `AGENTS.md` 指向的新路径存在。

## 影响范围

```yaml
affected_files:
  - control/AGENTS.md
  - control/README.md
  - control/profiles
  - control/scripts
  - control/templates
  - control/docs
  - control/openspec
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

## 后端

- 受影响模块：不涉及后端运行时代码。
- 事务边界：不涉及。
- 权限和租户：不涉及。

## 前端

- 页面：不涉及。
- 组件：不涉及。
- 状态：不涉及。

## 备选方案

- 方案：所有控制系统资产直接放入 `.ai-control/`。
- 取舍：路径更短，但项目画像和工具资产混在一起。
- 方案：使用目标项目根目录 `control/`。
- 取舍：路径更直观，但仍会占用业务项目根目录。
- 方案：OpenSpec 也迁入 `.ai-control/control/`。
- 取舍：根目录最清爽，但业务事实源可见性降低。

## 回滚方案

- 新安装项目可删除 `.ai-control/control/` 并重新按旧结构安装。
- 安装脚本改动可通过 git 回滚。
- 已存在旧结构的目标项目不自动迁移，因此不产生自动迁移回滚风险。
