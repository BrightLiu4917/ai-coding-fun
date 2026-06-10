# 通用规则目录

本目录放不同技术栈都要遵守的规则入口。

## 规则分层

- `.ai-control/control/docs/common/`：业务、接口、安全、测试、发布等跨技术栈规则。
- `.ai-control/control/docs/stacks/`：Java、Vue、React、Go、PHP 等技术栈规则。
- `.ai-control/control/docs/features/`：JWT、RBAC、CRUD、OpenAPI 等功能型规则。

## 使用原则

- 目标项目已有明确约定时，优先遵循目标项目。
- 目标项目没有约定时，再使用本控制系统默认规则。
- 业务规则必须来自 OpenSpec、项目上下文或用户确认，不能由 AI 自行发明。
- 技术规则可以指导实现，但不能覆盖已确认业务事实。

