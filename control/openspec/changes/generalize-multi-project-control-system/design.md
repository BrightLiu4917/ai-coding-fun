# 设计说明：多项目通用化控制系统

## 系统架构

控制系统采用三层结构：

- 项目适配层：`.ai-control/`、profile、项目检测脚本。
- 工程规则层：`AGENTS.md`、`agents/`、`docs/`、`openspec/`。
- 自动检查层：`scripts/`、CI 模板、deepv4 二审脚本。

## 模块设计

- `scripts/detect-project-profile.sh` 负责识别项目类型。
- `scripts/check-project-ready.sh` 负责接入后检查。
- `profiles/` 负责不同项目类型的安装清单。
- `docs/stacks/` 负责技术栈规则入口。
- `docs/features/` 负责 JWT、RBAC、CRUD、OpenAPI 等功能规则。

## 影响范围

```yaml
affected_files:
  - scripts
  - profiles
  - docs
  - agents
  - openspec
affected_tables:
  - none
affected_apis:
  - none
affected_pages:
  - none
affected_agents:
  - agent-architect
  - agent-openspec
  - agent-release
```

## 数据库设计

本变更不涉及数据库。

## 接口设计

本变更不涉及运行时接口。

## 流程设计

```text
用户执行安装脚本
-> 检测项目类型
-> 生成项目画像
-> 复制控制系统文件
-> 初始化 OpenSpec 和上下文
-> 运行接入检查
```

## 技术选型

- 继续使用 Bash，避免引入运行时依赖。
- 继续使用 Markdown，保持 AI 和用户都可直接阅读。
- 继续使用 profile 简单 TOML 子集，避免引入 TOML 解析器。

## 安全设计

- `.agent/` 默认忽略，避免提交密钥、日志和审查产物。
- `.ai-control/` 不放密钥，可以提交。
- deepv4 key 只允许写入 `.agent/deepv4.env`。

## 回滚方案

- 删除新增 profile、docs 子目录和检查脚本即可回到旧安装方式。
- 已安装到目标项目的控制文件可通过 git 回滚。

## 验证方案

- 运行 shell 语法检查。
- 运行 agent、路由、文档链接和 OpenSpec 检查。
- 使用临时 Spring Boot + Vue3 项目验证自动识别和安装。
