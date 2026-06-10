# 变更提案：后台审计日志查询

## 背景
后台管理操作需要可追踪的审计日志，便于定位误操作、权限问题和发布后问题。

## 变更内容
- 新增审计日志查询能力。
- 查询维度包括操作人、操作类型、业务对象、时间范围。
- 后端返回分页列表，不返回敏感请求参数。

## 非目标
- 不在本 change 中定义所有业务操作的写入规则。
- 不提供审计日志删除能力。
- 不修改登录、权限和租户模型。

## 影响
- 产品/业务：运营人员可查询管理操作记录。
- API：新增审计日志分页查询接口。
- 后端：新增查询 service 和 mapper。
- 数据库：需要确认目标项目是否已有审计日志表；没有明确表结构前不得实现。
- 测试：覆盖分页、筛选、权限和敏感字段隐藏。

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

## 风险
- 审计日志可能包含敏感字段，响应必须脱敏。
- 大表查询必须限制时间范围并使用索引。
- 后台审计日志属于高敏后台能力，必须确认访问控制模式、责任系统、权限点和越权处理。

## 待确认问题
- 审计日志表是否已经存在？
- 租户隔离字段名称是什么？
- 操作类型枚举有哪些已确认值？
- 后台审计日志查看权限点是否为 `admin:audit-log:view`，或由外部权限系统维护？
