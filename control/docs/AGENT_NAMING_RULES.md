# Agent 命名规则

## 目标

把 agent 做成普通工程手册，目录直观、名称短、易复制。

## 命名格式

```text
agents/agent-<name>.md
```

## 文档命名分层

- 面向用户阅读的手册、教程和流程说明使用中文文件名，例如 `快速开始.md`、`不同项目如何接入.md`。
- 面向脚本、agent、CI 和规则引用的文件使用稳定英文名，例如 `API_RULES.md`、`SPRING_BOOT_RULES.md`、`rules/41-spring-boot.md`。
- 禁止同一类文件同时使用多种命名风格。
- 中文文件名不得被脚本作为唯一机器入口；脚本入口必须使用英文稳定路径。

当前主入口和中文角色名：

```text
agent-spec      产品需求工程师
agent-spec     OpenSpec 规格工程师
agent-architect    系统架构师
agent-dev           UI 交互设计师
agent-dev          Web 前端开发工程师
agent-spec          API 契约工程师
agent-dev         Java 后端开发工程师
agent-dev           Go 后端开发工程师
agent-dev          PHP 后端开发工程师
agent-dba          数据库工程师
agent-dev      代码生成工程师
agent-test         测试工程师
agent-release     安全工程师
agent-release  性能工程师
agent-release      发布审查工程师
```

## 新增规则

- 必须放在 `agents/` 根目录。
- 文件名必须是 `agent-*.md`。
- 一级标题建议使用中文角色名，并在括号内保留 agent id，例如 `# 数据库工程师（agent-dba）`。
- 使用中文角色标题时，必须包含 `## 角色名称`。
- 正文使用中文，路径、命令、技术名保留英文。
- 每个 agent 必须包含 `## 职责` 和 `## 必须读取`。

## 后续扩展示例

```text
agents/agent-node.md
agents/agent-postgres.md
agents/agent-mobile.md
agents/agent-devops.md
```

## 禁止

- 禁止新增含义宽泛且无法执行的 agent。
- 禁止一个 agent 同时承载多个无关技术栈的实现细节。
- 禁止复制旧 agent 后只改名字。
- 禁止把未确认业务规则写进 agent。
