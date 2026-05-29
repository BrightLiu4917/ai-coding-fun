# 设计说明：后台审计日志查询

## 概述
查询能力以只读分页接口为边界。实现前必须通过数据库工程师（`agent-dba`）确认表结构、字段含义、索引和历史数据规模。

## API
- Method：`GET`
- 接口路径：`/api/admin/v1/audit-log/page`
- Auth：需要后台审计日志查看权限。
- 请求：分页参数、操作人、操作类型、业务对象、开始时间、结束时间。
- 响应：分页列表，隐藏敏感请求内容。

## 访问控制
- 访问控制模式：本服务 RBAC 示例；真实项目可改为外部权限服务、网关/IAM/SSO 或明确不适用。
- 本服务是否建设 RBAC：示例为是，真实项目以 `.ai-control/project.env` 和 OpenSpec 确认为准。
- 责任系统：示例为本服务。
- 允许角色：拥有审计日志查看权限的后台管理员或平台管理人员。
- 权限码或权限点：示例为 `admin:audit-log:view`，真实项目必须以既有权限模型为准。
- 菜单权限：审计日志菜单可见后才允许进入页面。
- 按钮权限：查询按钮不新增独立按钮权限，导出能力如后续新增必须单独确认权限码。
- 无权限处理：后端返回 `FORBIDDEN` 或目标项目统一 403 错误；前端显示无权限态。
- 越权处理：不得查询其他租户或超出数据范围的审计日志。

## 数据
- 表：待确认。
- 字段：待确认。
- 索引：建议待 DBA 根据实际查询条件确认。
- 迁移：没有明确 migration SQL 前不得修改表。

## 影响范围
```yaml
affected_files:
  - api/src/main/java
  - api/src/main/resources/mapper
affected_tables:
  - admin_audit_log
affected_apis:
  - GET /api/admin/v1/audit-log/page
affected_pages:
  - none
affected_agents:
  - agent-dba
  - agent-api
  - agent-java
  - agent-test
  - agent-security
  - agent-release
```

## 后端
- Controller 只做参数接收和响应包装。
- Service 负责业务校验、权限检查和查询条件组装。
- Mapper/XML 只承载 SQL。
- 查询必须包含租户隔离和软删除条件，如项目存在这些模型。

## 回滚
只读接口可通过下线路由或回滚代码关闭；如后续涉及建表，必须提供单独 rollback SQL。
