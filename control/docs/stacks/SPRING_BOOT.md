# Spring Boot 技术栈规则

## 适用范围

适用于 Java 17+、Spring Boot 3/4、Maven/Gradle、MyBatis 或 MyBatis-Plus 后端项目。

本文件是 Spring Boot 技术栈入口规则；详细实现约束以 `.ai-control/control/docs/SPRING_BOOT_RULES.md` 为准。

读取顺序：

1. 先读 `.ai-control/control/docs/stacks/SPRING_BOOT.md` 判断是否适用。
2. 再读 `.ai-control/control/docs/SPRING_BOOT_RULES.md` 获取依赖分级、ID、异常、事务和 DTO/VO 细则。
3. 最后按目标项目既有代码确认实际包结构、响应体、异常、分页、权限和 Mapper/XML 风格。

## 接入原则

- 优先读取目标项目已有包结构、统一响应、异常体系、分页对象、权限注解、租户上下文和 Mapper/XML 风格。
- 目标项目没有约定时，再使用本控制系统默认的 DTO/VO、ID、事务和依赖规则。
- Spring Boot 版本必须跟随目标项目；禁止为了脚手架强行升级。
- 依赖按“必须依赖、功能依赖、脚手架依赖、测试依赖”分级处理。

## 默认关注点

- Controller 薄入口。
- Service 承载业务动作和事务边界。
- Mapper/XML 显式字段，禁止 `SELECT *`。
- API 对外暴露 `id`，数据库内部可保留 `pk_id`。
- 长整型 ID 给前端时按字符串处理。
- 参数非法返回参数错误，数据不存在返回业务不存在。
