# gupo Java Spring Boot CRUD Adapter

本 adapter 只适用于 gupo 项目。

它依赖 gupo 项目的封装和约定，包括但不限于：
- 包结构和基础目录。
- 返回体封装。
- 分页封装。
- 异常体系。
- Controller、Service、Mapper/XML 分层约定。
- DTO/VO/Model 命名和路径。
- 管理端接口路径约定。

## Scripts

```text
scripts/crud-spring-bootv2
scripts/crud-spring-bootv34
```

选择规则：
- Spring Boot 2.x 使用 `crud-spring-bootv2`
- Spring Boot 3.x / 4.x 使用 `crud-spring-bootv34`

## 使用原则

- 必须先确认 adapter 为 `gupo`。
- 必须先 `--preview`。
- 无法从 `pom.xml` 判断 Spring Boot 版本时必须询问。
- 覆盖已有文件必须等待 force token 和用户确认。
- 禁止用于非 gupo 项目。
- 禁止伪装为通用 Spring Boot CRUD 脚手架。
