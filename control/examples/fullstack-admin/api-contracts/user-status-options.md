# API 契约：用户状态选项

## 接口说明
- 请求方法：`GET`
- 接口路径：`/api/admin/v1/user/status-options`
- 鉴权方式：`admin:user:view`

## 请求
```json
{}
```

## 响应
```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "label": "正常",
      "value": "ACTIVE"
    }
  ]
}
```

## 错误码
- `FORBIDDEN`: 无用户列表查看权限。

## 分页说明
- list/data: 不分页，返回 `data` 数组。
- total: 不适用。
- pageNum/current: 不适用。
- pageSize: 不适用。

## 兼容性
- 是否兼容：新增接口，不破坏既有接口。
- 影响前端：用户列表筛选控件依赖该接口。

## 鉴权说明
- 访问控制模式：本服务 RBAC 示例，真实项目可改为外部权限系统负责。
- 权限码或权限点：`admin:user:view`
- 允许角色：拥有用户列表查看权限的后台运营人员或平台管理人员。
- 无权限返回：`FORBIDDEN` 或目标项目统一 403 错误。

## 安全说明
- 敏感字段：不返回用户数据。
- 权限：需要用户列表查看权限。
- 租户：如果状态选项受租户配置影响，必须按当前租户返回。
