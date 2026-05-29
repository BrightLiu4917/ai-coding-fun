# 上下文地图

默认使用根目录 `CONTEXT.md` 作为 AI 全栈控制系统的统一术语表。`CONTEXT-MAP.md` 只负责说明上下文如何分层、何时拆分、不同目录之间谁是事实源。

复制到具体业务项目后，如果业务上下文复杂，可以拆分为多上下文结构：

```text
CONTEXT-MAP.md
docs/adr/
apps/admin/CONTEXT.md
services/billing/CONTEXT.md
services/appointment/CONTEXT.md
```

## 上下文

- [控制系统上下文](./CONTEXT.md)：OpenSpec、Agent、Agent Route、Profile、Review Gate 等控制系统术语。
- `openspec/project.md`：目标项目的产品、技术栈、范围和治理说明。
- `openspec/specs/`：已确认能力规格。
- `openspec/changes/`：待确认或执行中的变更。
- `docs/`：工程规则和审查标准。
- `agents/`：角色化执行规则。
- `profiles/`：安装组合。
- `templates/`：标准产物模板。

## 拆分建议

### 小型项目

只维护：

```text
CONTEXT.md
openspec/project.md
openspec/specs/
openspec/changes/
```

### 中大型项目

按业务域或应用拆分：

```text
CONTEXT.md
CONTEXT-MAP.md
apps/admin/CONTEXT.md
apps/supplier/CONTEXT.md
services/auth/CONTEXT.md
services/order/CONTEXT.md
openspec/specs/auth/spec.md
openspec/specs/supplier-onboarding/spec.md
```

### 多技术栈项目

按技术栈和业务能力共同定位：

```text
.ai-control/project.env
docs/stacks/SPRING_BOOT.md
docs/stacks/VUE3.md
docs/features/JWT_RULES.md
docs/features/RBAC_RULES.md
```

## 关系

- `AGENTS.md` 负责全局红线和高层入口。
- `docs/AGENT_ROUTING.md` 负责 agent 顺序、并行、循环、回退和冲突处理。
- `CONTEXT.md` 负责共同语言，不承载已确认业务规则。
- `openspec/specs/` 承载已确认规格。
- `docs/adr/` 只记录长期架构决策；普通需求不要写入 ADR。
- `profiles/` 影响安装范围，不改变运行时业务行为。

## 冲突处理

- `openspec/specs/` 与 `api-contracts/` 冲突时，以已确认规格为准。
- `docs/stacks/` 与目标项目既有代码冲突时，以目标项目既有约定为准。
- `.ai-control/project.env` 与实际项目结构冲突时，应重新运行检测脚本或手工修正项目画像。
- `CONTEXT.md` 中的术语与 OpenSpec 已确认规格冲突时，以 OpenSpec 为准，并同步修正 `CONTEXT.md`。
