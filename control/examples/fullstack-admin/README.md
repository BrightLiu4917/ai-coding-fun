# 全栈管理端示例

本示例展示前后端同仓管理端如何使用控制系统串联产品、设计、API、DB、前端、后端、QA 和发布审查。示例只描述流程和文档，不代表真实业务规则。

前后端同仓建议：

```text
your-admin/
├── AGENTS.md
├── openspec/
├── .ai-control/
├── backend/
└── frontend/
```

## 推荐安装

```bash
bash control/scripts/install-to-project.sh --dry-run --profile default /path/to/your-admin
bash control/scripts/install-to-project.sh --backup --profile default /path/to/your-admin
```

## 管理端流程

管理端新功能默认流程：

```text
agent-product
-> agent-openspec
-> agent-ui
-> agent-api
-> agent-dba，如涉及数据库
-> agent-web / agent-java，可在 API 契约确认后并行
-> agent-test
-> agent-release
```

## 示例文件

- `openspec/changes/add-user-status-filter/`：管理端筛选能力 OpenSpec change 示例。
- `api-contracts/user-status-options.md`：前后端 API 契约示例。
- `review-report.md`：发布前审查报告示例。

## API contract 和 OpenSpec 的关系

- `openspec/changes/add-user-status-filter/` 是事实源，记录范围、设计、任务和规格。
- `api-contracts/user-status-options.md` 是接口契约展开文档，服务前后端联调。
- 如果两者冲突，以 OpenSpec 中已确认的规格为准，并同步更新 API contract。
