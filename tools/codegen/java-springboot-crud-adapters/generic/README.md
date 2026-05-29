# 通用 Java Spring Boot CRUD 预览 Adapter

本 adapter 是通用 Java Spring Boot CRUD 的预览工具，不是生产代码生成器。

它只生成审查用草稿包，默认不写文件；即使使用 `--write`，也只写入 `.agent/codegen-preview/<EntityName>/`，不会直接修改业务源码目录。

## ID 和前端精度规则

- 数据库可以保留内部自增主键 `pk_id`。
- 对外 API 统一使用 `id`。
- 生成的 API 请求和响应草稿中，`id` 使用 `String`，避免前端长整型精度丢失。
- 前端必须按字符串处理 `id`，禁止转 `Number`。
- 后端内部可以把 API 字符串 `id` 校验后转换为 `Long`。
- `id` 非法时返回参数错误；查不到数据时返回业务不存在，不允许变成 500。
- generic 预览草稿不输出 `[CRUD-CODEGEN]` 这类脚手架说明注释。

## 使用方式

```bash
bash tools/codegen/java-springboot-crud-adapters/generic/scripts/crud-preview \
  --project-root /path/to/project \
  --base-package com.example.demo \
  --entity-name Supplier \
  --table-name supplier \
  --route-path /api/suppliers \
  --display-name 供应商 \
  --fields 'id:Long:主键,name:String:名称,status:String:状态'
```

写入审查草稿：

```bash
bash tools/codegen/java-springboot-crud-adapters/generic/scripts/crud-preview \
  --project-root /path/to/project \
  --base-package com.example.demo \
  --entity-name Supplier \
  --table-name supplier \
  --route-path /api/suppliers \
  --display-name 供应商 \
  --fields 'id:Long:主键,name:String:名称,status:String:状态' \
  --write
```

## 安全规则

- 禁止对非 gupo 项目使用 gupo adapter。
- 禁止把 preview draft 当成已确认实现。
- 禁止绕过 OpenSpec、DBA、API contract、权限、租户和测试确认。
- 真实落地必须经用户确认后转入 Java 后端开发工程师（`agent-java`）或项目专用 adapter。
- 覆盖业务源码必须通过单独确认的实现流程完成。
