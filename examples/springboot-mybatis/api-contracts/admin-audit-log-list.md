# API 契约：后台审计日志列表

## 接口说明
- 请求方法：`GET`
- 接口路径：`/api/admin/v1/audit-log/page`
- 鉴权方式：`admin:audit-log:view`

## 请求
```json
{
  "pageNum": 1,
  "pageSize": 20,
  "operatorId": 10001,
  "operationType": "UPDATE",
  "targetType": "USER",
  "startTime": "2026-05-01T00:00:00+08:00",
  "endTime": "2026-05-09T23:59:59+08:00"
}
```

## 响应
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "list": [
      {
        "id": 1,
        "operatorId": 10001,
        "operatorName": "admin",
        "operationType": "UPDATE",
        "targetType": "USER",
        "targetId": "20001",
        "summary": "更新用户状态",
        "createdAt": "2026-05-09T10:30:00+08:00"
      }
    ],
    "total": 1,
    "pageNum": 1,
    "pageSize": 20
  }
}
```

## 错误码
- `FORBIDDEN`: 无审计日志查看权限。
- `INVALID_TIME_RANGE`: 时间范围无效。

## 分页说明
- list/data: `data.list`
- total: `data.total`
- pageNum/current: `data.pageNum`
- pageSize: `data.pageSize`

## 兼容性
- 是否兼容：新增接口，不破坏既有接口。
- 影响前端：需要新增审计日志列表页或接入既有页面。

## 鉴权说明
- 访问控制模式：本服务 RBAC 示例，真实项目可改为外部权限系统负责。
- 权限码或权限点：`admin:audit-log:view`
- 允许角色：拥有审计日志查看权限的后台管理员或平台管理人员。
- 无权限返回：`FORBIDDEN` 或目标项目统一 403 错误。

## 安全说明
- 敏感字段：不返回完整请求体、密码、token、private key 或生产连接串。
- 权限：需要审计日志查看权限。
- 租户：如项目存在租户模型，必须按租户隔离。
