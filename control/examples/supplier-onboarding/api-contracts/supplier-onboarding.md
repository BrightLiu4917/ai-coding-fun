# API 契约：供应商入驻

本文件是示例契约，不是已确认项目 API。

## 接口清单
- `POST /api/app/v1/supplier-onboarding/submit`：供应商提交入驻申请。
- `GET /api/app/v1/supplier-onboarding/detail`：供应商查看当前入驻申请。
- `GET /api/admin/v1/supplier-onboarding/page`：平台管理查看入驻申请列表。
- `POST /api/admin/v1/supplier-onboarding/review`：平台管理审核入驻申请。

## 请求说明

### 供应商提交申请

```http
POST /api/app/v1/supplier-onboarding/submit
```

请求字段待确认，以下仅为示例：

```json
{
  "organizationName": "Example Supplier",
  "contactName": "Example Contact",
  "contactPhone": "13800000000",
  "licenseFileId": "file_001"
}
```

### 平台管理审核申请

```http
POST /api/admin/v1/supplier-onboarding/review
```

请求示例：

```json
{
  "id": "123",
  "decision": "APPROVED",
  "reason": "资料已核验"
}
```

## 响应说明

响应包装必须遵循目标项目。

### 供应商当前申请

```http
GET /api/app/v1/supplier-onboarding/detail
```

返回供应商可见的当前入驻状态和审核结果。

### 平台审核列表

```http
GET /api/admin/v1/supplier-onboarding/page
```

查询参数和分页格式必须遵循目标项目。

## 错误码
- 待确认：响应包装。
- 待确认：错误码格式。
- 待确认：鉴权策略。
- 待确认：权限模型。
- 待确认：分页模型。
- 待确认：敏感资料可见性。

## 分页说明
- 平台审核列表需要分页。
- 分页字段必须遵循目标项目。

## 兼容性
- 示例接口不代表真实项目已确认路径。
- 实现前必须对齐目标项目响应包装、错误码、鉴权和权限模型。

## 鉴权说明
- 访问控制模式：本服务 RBAC 示例，真实项目可改为外部权限系统负责。
- 权限码或权限点：示例为 `supplier:onboarding:submit`、`supplier:onboarding:view`、`platform:supplier-onboarding:view`、`platform:supplier-onboarding:review`。
- 允许角色：供应商只能访问自己的入驻申请；平台管理只能访问审核列表和审核动作。
- 无权限返回：`FORBIDDEN` 或目标项目统一 403 错误。

## 安全说明
- 敏感资料不得返回给未授权角色。
- 平台管理接口必须校验平台管理权限。
- 供应商只能查看自己的入驻申请。
