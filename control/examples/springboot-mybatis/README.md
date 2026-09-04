# Spring Boot + MyBatis 示例

本示例展示一个 Java Spring Boot + MyBatis/MyBatis-Plus 后端项目如何接入控制系统。示例只描述目录、流程和文档，不代表真实业务规则。

## 推荐安装

```text
your-project/
├── AGENTS.md
├── openspec/
├── .ai-control/
├── pom.xml
└── src/
```

```bash
bash control/scripts/install-to-project.sh --dry-run --profile minimal /path/to/your-project
bash control/scripts/install-to-project.sh --backup --profile minimal /path/to/your-project
```

## 后端任务流程

后端任务默认流程：

```text
agent-spec
-> agent-dba，如涉及表结构、SQL、索引或数据兼容
-> agent-spec，如涉及接口
-> agent-dev，如涉及 CRUD 脚手架，先识别 adapter
-> agent-dev
-> agent-test
-> agent-release
```

## 示例文件

- `openspec/changes/add-admin-audit-log/`：后端审计日志能力的 OpenSpec change 示例。
- `api-contracts/admin-audit-log-list.md`：API 契约示例。
- `review-report.md`：发布前审查报告示例。

## API contract 和 OpenSpec 的关系

- `openspec/changes/add-admin-audit-log/` 是事实源，记录范围、设计、任务和规格。
- `api-contracts/admin-audit-log-list.md` 是接口契约展开文档，服务前后端联调和后端自测。
- 如果两者冲突，以 OpenSpec 中已确认的规格为准，并同步更新 API contract。
