# 变更提案：供应商入驻

## 总结
新增供应商注册、资料提交和平台审核流程。

## 背景
供应商参与招标活动前需要完成受控入驻流程。平台管理需要审核队列，用于批准或驳回供应商入驻申请。

## 范围
- 供应商提交注册信息和入驻资料。
- 平台管理审核已提交资料。
- 供应商查看入驻结果。
- 系统记录审核决定和原因。

## 影响范围
```yaml
affected_files:
  - api/src/main/java
  - vue/src/views
  - vue/src/api
affected_tables:
  - supplier_onboarding_application
  - supplier_profile
affected_apis:
  - POST /api/app/v1/supplier-onboarding/submit
  - GET /api/app/v1/supplier-onboarding/detail
  - GET /api/admin/v1/supplier-onboarding/page
  - POST /api/admin/v1/supplier-onboarding/review
affected_pages:
  - /supplier/onboarding
  - /platform/supplier-onboarding
affected_agents:
  - agent-product
  - agent-api
  - agent-dba
  - agent-java
  - agent-web
  - agent-security
  - agent-release
```

## 非目标
- 本变更不实现专家入驻。
- 本变更不实现投标申请。
- 本变更不定义支付、套餐扣减或通知规则。
- 本变更不推断租户规则。

## 待确认问题
- 供应商注册身份来源和登录方式尚未确认。
- 资料字段仅为示例，真实实现前必须确认。
- 审核状态仅为示例，真实实现前必须确认。
- API 响应包装和错误码格式必须遵循目标项目。
- 供应商和平台管理的访问控制模式、责任系统、权限点、菜单权限、按钮权限和越权处理必须确认。
