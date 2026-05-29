# 变更提案：用户状态筛选

## 背景
运营人员在用户列表中需要按状态筛选用户，以便快速定位待处理、已禁用或异常用户。

## 变更内容
- 在用户列表增加状态筛选控件。
- 前端从后端读取可用状态选项。
- 列表查询带上已选择状态。

## 非目标
- 不新增或修改用户状态枚举。
- 不改变用户状态流转规则。
- 不改变用户详情页或批量操作。

## 影响
- UX/UI：用户列表增加状态筛选。
- 前端：列表筛选状态和查询参数同步。
- API：新增或复用状态选项接口，列表接口增加筛选参数需确认兼容性。
- 后端：提供状态选项或支持筛选参数。
- 数据库：不改表结构。

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
  - agent-ui
  - agent-api
  - agent-web
  - agent-java
  - agent-security
  - agent-test
  - agent-release
```

## 风险
- 状态枚举必须来自既有后端事实源，不能由前端硬编码发明。
- 筛选后空态需要区分无数据和筛选无结果。
- 状态选项和用户列表属于后台能力，必须确认访问控制模式、责任系统、权限点和无权限处理。

## 待确认问题
- 既有用户状态枚举来源在哪里？
- 用户列表接口是否已经支持状态筛选参数？
- 状态选项是否受权限或租户影响？
- 后台用户列表查看权限点是否为 `admin:user:view`，或由外部权限系统维护？
