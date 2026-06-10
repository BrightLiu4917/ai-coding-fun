# Codex 全栈任务入口模板

> 先按任务分级判断。非简单任务必须先进入 OpenSpec change，不要直接编码。

## 项目
填写项目名

## 能力/模块
填写业务能力名，例如：tenant、appointment、payment、admin-user、dashboard

## 任务
填写具体目标

## 用户和业务目标
- 目标用户：
- 业务目标：
- 成功指标：

## 已确认业务规则
1. 填写已经确认的规则。
2. 不确定的规则写到“待确认问题”，禁止当作已确认规则。

## 影响范围
- 产品/业务：
- UX/UI：
- 前端：
- API：
- 后端：
- 数据库：
- 测试：
- 发布：

## 任务分级
选择一个：

- 简单任务：只改单个文档、注释、格式或明显 typo，不涉及业务、DB、SQL、API、权限、租户、状态流、删除、运行时代码或前后端契约。
- 低风险批量修改：只改配置、常量、文案、注释、格式、非业务模板或规则文档；可跨多个文件，但不改变业务行为、DB、API、权限、目录结构或线上数据。
- 非简单任务：不满足以上条件，必须进入 OpenSpec。

低风险批量修改编码前仍需输出范围、受影响文件和验证方式。

## OpenSpec 要求
请先创建或读取：

```text
openspec/changes/<change-id>/
├── proposal.md
├── design.md
├── tasks.md
└── specs/
    └── <capability>/
        └── spec.md
```

编码前必须输出并等待我确认：
1. 需求理解
2. 功能范围和非范围
3. 受影响 OpenSpec specs/changes
4. 设计方案，如需要
5. ToDo List
6. 风险点和缺失点
7. 待确认建议
8. 需要我确认的问题

## Matt-style 工程方法
- 需求不清：用 `agent-product` 做追问、术语校准和场景压力测试。
- 需要进入规格流程：用 `agent-openspec` 创建或完善 OpenSpec change。
- 需要把追问结果落到 OpenSpec：用 `agent-openspec`。
- 代码区域陌生：用 `agent-architect` 先建立能力地图。
- Bug 或性能问题：用 `agent-architect` 建立反馈回路后再修。
- 需要测试保护：用 `agent-test` 或对应前端测试 agent 做红绿重构。
- 解耦重构：用 `agent-architect` 找 deep module、seam 和分批切片。
- 详细 agent 路由、并行、循环、回退和冲突处理：按 `.ai-control/control/docs/AGENT_ROUTING.md`。

## 强制停止条件
如果以下内容不清楚，必须 STOP and ASK：
- 用户角色或业务目标
- DB 字段
- 枚举值
- 状态流转
- 权限规则
- 租户规则
- 删除行为
- API 路径或响应结构
- 页面交互、空态、错误态、权限态
- 支付/套餐扣减规则
- OpenSpec 规格与现有代码冲突

## 输出要求
1. 先提供 OpenSpec change 预审和实施计划。
2. 涉及表结构或字段变化时，明确列出表名、字段名、变化类型、旧定义、新定义、影响范围、是否需要迁移。
3. 等我确认后再实施最小安全变更。
4. 报告 OpenSpec 变化、变更文件、关键逻辑、SQL 变更、表结构/字段变化、API 变化、前端变化、验证步骤和风险。

## 推荐验证
- `bash .ai-control/control/scripts/agent-check.sh`
- `bash .ai-control/control/scripts/route-check.sh`
- `bash .ai-control/control/scripts/docs-link-check.sh`
- `bash .ai-control/control/scripts/openspec-check.sh openspec/changes/<change-id>`
- `bash .ai-control/control/scripts/run-tests.sh`
