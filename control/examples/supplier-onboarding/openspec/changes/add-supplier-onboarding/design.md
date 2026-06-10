# 设计说明：供应商入驻

## 需求理解
完整系统包含平台管理、专家和供应商三类角色。本示例只覆盖供应商入驻。

供应商提交资料，平台管理审核申请，供应商可查看当前结果。

## 领域草稿
- 供应商档案：入驻审核通过后的组织身份。
- 入驻申请：一次已提交的审核请求。
- 审核决定：平台管理对申请做出的决定。

## 状态候选示例
以下状态不是已确认业务规则：
- `DRAFT`
- `SUBMITTED`
- `APPROVED`
- `REJECTED`

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
  - agent-release
```

## 数据安全
- 数据库工程师确认字段、索引和回滚 SQL 前，不创建或修改表。
- 审核写操作如果同时更新申请和供应商档案，必须使用事务。
- 禁止全表更新或删除。

## API 安全
- 响应包装、分页和错误码必须使用目标项目约定。
- 敏感资料不得返回给未授权角色。
- 平台管理接口必须强制校验角色权限。

## 访问控制
- 访问控制模式：本服务 RBAC 示例；真实项目可改为外部权限服务、网关/IAM/SSO 或明确不适用。
- 本服务是否建设 RBAC：示例为是，真实项目以 `.ai-control/project.env` 和 OpenSpec 确认为准。
- 责任系统：示例为本服务。
- 允许角色：供应商只能提交和查看自己的入驻申请；平台管理只能处理审核列表和审核动作。
- 权限码或权限点：示例为 `supplier:onboarding:submit`、`supplier:onboarding:view`、`platform:supplier-onboarding:view`、`platform:supplier-onboarding:review`，真实项目必须以既有权限模型为准。
- 菜单权限：供应商入驻菜单和平台供应商入驻审核菜单分别控制。
- 按钮权限：平台审核通过、驳回按钮必须有独立按钮权限或明确复用审核权限。
- 无权限处理：后端返回 `FORBIDDEN` 或目标项目统一 403 错误；前端显示无权限态。
- 越权处理：供应商不得查看或修改其他供应商申请，平台管理不得绕过租户或组织数据范围。

## 实施计划
1. 确认字段、状态、权限和响应包装。
2. 数据库工程师设计表结构和迁移 SQL。
3. API 契约工程师审查接口契约。
4. Java 后端开发工程师实现最小已确认流程。
5. Web 前端开发工程师实现供应商提交页和平台审核页。
6. 运行测试和发布审查。
