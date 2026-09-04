# 设计说明：用户状态筛选

## 产品和交互
- 入口：用户列表页。
- 主流程：进入列表，展开或查看筛选区，选择状态，列表刷新。
- 空态：筛选无结果时显示筛选条件无匹配，不显示“无权限”。
- 错误态：状态选项加载失败时保留列表可用，并提供重试。

## API
- 状态选项接口：待确认是否已有。
- 用户列表接口：如新增 `status` 查询参数，必须保持向后兼容。

## 数据
- 不修改表结构。
- 不新增状态枚举。

## 影响范围
```yaml
affected_files:
  - vue/src/views
  - vue/src/api
affected_tables:
  - none
affected_apis:
  - GET /api/admin/v1/user/status-options
  - GET /api/admin/v1/user/page
affected_pages:
  - 用户列表页
affected_agents:
  - agent-dev
  - agent-spec
  - agent-dev
  - agent-release
  - agent-test
  - agent-release
```

## 访问控制
- 访问控制模式：本服务 RBAC 示例；真实项目可改为外部权限服务、网关/IAM/SSO 或明确不适用。
- 本服务是否建设 RBAC：示例为是，真实项目以 `.ai-control/project.env` 和 OpenSpec 确认为准。
- 责任系统：示例为本服务。
- 允许角色：拥有用户列表查看权限的后台运营人员或平台管理人员。
- 权限码或权限点：示例为 `admin:user:view`，真实项目必须以既有权限模型为准。
- 菜单权限：用户管理菜单可见后才展示用户列表页。
- 按钮权限：状态筛选不新增独立按钮权限，除非目标项目已有筛选权限模型。
- 无权限处理：后端返回 `FORBIDDEN` 或目标项目统一 403 错误；前端显示无权限态，不展示不可见状态。
- 越权处理：不得通过前端硬编码状态绕过后端权限或租户限制。

## 前端
- 状态选项从 API 或已确认常量读取。
- 筛选条件进入 URL query 或既有列表状态管理，遵循项目约定。
- 加载态、错误态和空态必须覆盖。

## 后端
- 如已有状态枚举，后端返回 label/value。
- 如列表接口已有筛选参数，仅做契约确认。

## 回滚
前端移除筛选控件并停止传参；如新增状态选项接口，可回滚接口代码。
