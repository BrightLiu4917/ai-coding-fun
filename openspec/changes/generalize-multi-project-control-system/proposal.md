# 变更提案：多项目通用化控制系统

## 项目背景

控制系统需要面向不同技术栈和不同业务项目使用，不能绑定某个历史项目、全局 skill 或固定目录结构。

## 项目目标

- 自动识别目标项目技术栈并生成项目画像。
- 支持 Spring Boot、Vue3、React、Go、PHP 等常见项目类型。
- 将规则拆分为通用规则、技术栈规则和功能规则。
- 明确 `.agent/` 和 `.ai-control/` 的边界。
- 让新用户通过中文文档快速接入。

## 功能范围

- 项目检测和项目画像。
- 多技术栈 profile。
- 规则分层和中文用户文档。
- 接入检查、CI 检查和示例补齐。

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

## 非目标

- 不实现业务运行时代码。
- 不自动安装 JDK、Node、Docker、MySQL 或 Redis。
- 不调用或依赖用户全局 `~/.codex/skills`。

## 风险说明

- profile 过多会增加维护成本，需要通过检查脚本保证路径有效。
- `.agent/` 忽略是正确策略，但必须保留模板和文档说明，避免用户误解。
- 中文用户文档和英文规则文件并存，需要明确命名规则。

## 待确认问题

- 后续是否为 Node/NestJS、PostgreSQL、移动端项目补专用 agent。
- 是否将 profile 安装范围做得更轻量，减少示例文件复制。
