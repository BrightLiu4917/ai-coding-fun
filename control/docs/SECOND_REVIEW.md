# 独立二审约定

## 定位
独立二审是第二审查者，用于独立检查复杂逻辑和风险点。它不替代 OpenSpec、AI 助手最终 Review 或人工业务确认。

## 触发场景
- 数据库表结构、迁移 SQL、回滚 SQL 或历史数据处理。
- 支付、套餐扣减、库存、余额、结算等资金或扣减逻辑。
- 权限、租户隔离、数据可见范围或越权风险。
- 状态流转、并发、幂等、重复提交。
- 跨模块流程或发布前高风险变更。

## 输入
使用 [`templates/review-input.md`](../templates/review-input.md)，只提供必要上下文：

- OpenSpec change 摘要。
- 已确认业务规则。
- `git diff` 或关键文件片段。
- 测试结果摘要。
- 需要重点检查的问题。

不要提供生产密钥、真实连接串、用户隐私数据或完整无关日志。

## 输出
独立二审只输出审查意见：

- 阻塞问题。
- 重要风险。
- 待确认问题。
- 建议补充测试。

建议不能直接当作已确认业务规则。影响正确性的建议必须回到 OpenSpec 或由用户确认。

## OpenAI-compatible 调用
推荐通过 OpenAI-compatible API 接入独立二审。小白优先在初始化时配置：

```bash
bash .ai-control/control/scripts/ai-dev.sh init
```

脚本询问是否启用独立二审时选择启用，然后输入 `REVIEW_BASE_URL`、`REVIEW_API_KEY` 和 `REVIEW_MODEL`。

高级用户也可以直接在 `.agent/review.env` 中配置：

```bash
REVIEW_BASE_URL='https://api.example.com/v1'
REVIEW_API_KEY='replace-with-your-key'
REVIEW_MODEL='独立二审'
REVIEW_TEMPERATURE='0.1'
REVIEW_COMMAND='bash .ai-control/control/scripts/providers/openai-compatible.sh'
```

真实 key 只能写在 `.agent/review.env`，禁止提交。

## 脚本流程
准备审查输入：

```bash
bash .ai-control/control/scripts/prepare-review.sh
```

这会生成：

```text
.agent/reviews/review-input.md
```

运行独立二审：

```bash
bash .ai-control/control/scripts/run-review.sh
```

这会生成：

```text
.agent/reviews/review-output.md
```

未配置 `REVIEW_COMMAND` 时，流程会跳过自动调用，并在输出中说明“独立二审未运行”。

## 输入控制
`prepare-review.sh` 默认收集：

- OpenSpec proposal/design/tasks 摘要，如设置了 `OPENSPEC_CHANGE_ID`。
- `.ai-control/control/scripts/summarize-log.sh` 的测试摘要。
- `git diff --stat`。
- 当前 `git diff`，排除 `.agent`、`node_modules`、`dist` 和 `target`。

不要把生产密钥、真实连接串、用户隐私数据或完整无关日志放入独立二审输入。
