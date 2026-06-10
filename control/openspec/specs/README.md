# OpenSpec 规格

`specs/` 是当前项目已确认行为的事实源。

建议按业务能力拆分：

```text
openspec/specs/tenant/spec.md
openspec/specs/user/spec.md
openspec/specs/payment/spec.md
openspec/specs/appointment/spec.md
openspec/specs/dashboard/spec.md
```

每个 `spec.md` 至少包含：
- 能力边界
- 角色和权限
- 状态枚举
- 工作流
- 数据规则
- API 或页面契约，如适用
- 可验收场景

禁止把未确认规则写成已确认事实。
