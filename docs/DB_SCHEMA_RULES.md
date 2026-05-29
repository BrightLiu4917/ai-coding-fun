# 数据库结构规则

## MySQL 基线
- MySQL 8
- 字符集：`utf8mb4`
- 推荐排序规则：`utf8mb4_unicode_ci`，除非既有表已经使用其他排序规则。

## 主键和业务 ID
- 数据库可以保留 `pk_id` 作为内部自增主键。
- 对外 API 和前端统一使用业务 ID `id`。
- `id` 如使用雪花算法或其他长整型，前端必须按字符串处理。
- 禁止把 `pk_id`、`pkId`、`pk_id_list` 或 `pkIdList` 暴露为 API 请求/响应字段。
- 后端内部可把 API 字符串 `id` 校验后转换为 `Long` 查询。

## 基础字段建议
业务表应考虑：

```sql
`pk_id` bigint NOT NULL AUTO_INCREMENT COMMENT '数据库主键',
`id` bigint NOT NULL COMMENT '业务ID，雪花算法生成',
`tenant_id` bigint NOT NULL DEFAULT 0 COMMENT '租户ID',
`is_deleted` tinyint NOT NULL DEFAULT 0 COMMENT '是否删除：0否 1是',
`gmt_created` datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
`gmt_modified` datetime(3) NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
`gmt_deleted` datetime(3) NULL COMMENT '删除时间',
`create_by` varchar(255) NULL COMMENT '创建人',
`update_by` varchar(255) NULL COMMENT '更新人'
```

## SQL 规则
- 禁止 `SELECT *`。
- 必须显式列名。
- UPDATE/DELETE 必须有精确 WHERE。
- 存在租户上下文时必须带租户条件。
- 存在软删除时必须带软删除条件。
- 避免索引字段函数计算。
- 避免隐式类型转换。

## 变更要求
每次结构变更必须提供：
- forward SQL
- rollback SQL，如存在风险
- 历史数据兼容策略
- 索引影响
- Entity/Mapper/XML/DTO/VO/API 联动清单

## 高风险操作
CREATE、UPDATE、DELETE、ALTER、DROP、TRUNCATE 执行前必须确认。
DROP/TRUNCATE 默认先备份，备份表名：`原表名_copy_yyyyMMdd`。
