# deepv4 二审约定

## 定位
deepv4 是第二审查者，用于独立检查复杂逻辑和风险点。它不替代 OpenSpec、Codex 最终 Review 或人工业务确认。

## 触发场景
- 数据库表结构、迁移 SQL、回滚 SQL 或历史数据处理。
- 支付、套餐扣减、库存、余额、结算等资金或扣减逻辑。
- 权限、租户隔离、数据可见范围或越权风险。
- 状态流转、并发、幂等、重复提交。
- 跨模块流程或发布前高风险变更。

## 输入
使用 [`templates/deepv4-review-input.md`](../templates/deepv4-review-input.md)，只提供必要上下文：

- OpenSpec change 摘要。
- 已确认业务规则。
- `git diff` 或关键文件片段。
- 测试结果摘要。
- 需要重点检查的问题。

不要提供生产密钥、真实连接串、用户隐私数据或完整无关日志。

## 输出
deepv4 只输出审查意见：

- 阻塞问题。
- 重要风险。
- 待确认问题。
- 建议补充测试。

建议不能直接当作已确认业务规则。影响正确性的建议必须回到 OpenSpec 或由用户确认。

## OpenAI-compatible 调用
推荐通过 OpenAI-compatible API 接入 deepv4。小白优先在初始化时配置：

```bash
bash scripts/ai-dev.sh init
```

脚本询问是否启用 deepv4 时选择启用，然后输入 `DEEPV4_BASE_URL`、`DEEPV4_API_KEY` 和 `DEEPV4_MODEL`。

高级用户也可以直接在 `.agent/deepv4.env` 中配置：

```bash
DEEPV4_BASE_URL='https://api.example.com/v1'
DEEPV4_API_KEY='replace-with-your-key'
DEEPV4_MODEL='deepv4'
DEEPV4_TEMPERATURE='0.1'
DEEPV4_REVIEW_COMMAND='bash scripts/providers/deepv4-openai-compatible.sh'
```

真实 key 只能写在 `.agent/deepv4.env`，禁止提交。

## 脚本流程
准备审查输入：

```bash
bash scripts/prepare-deepv4-review.sh
```

这会生成：

```text
.agent/reviews/deepv4-input.md
```

运行 deepv4 二审：

```bash
bash scripts/run-deepv4-review.sh
```

这会生成：

```text
.agent/reviews/deepv4-output.md
```

未配置 `DEEPV4_REVIEW_COMMAND` 时，流程会跳过自动调用，并在输出中说明“deepv4 二审未运行”。

## 输入控制
`prepare-deepv4-review.sh` 默认收集：

- OpenSpec proposal/design/tasks 摘要，如设置了 `OPENSPEC_CHANGE_ID`。
- `scripts/summarize-log.sh` 的测试摘要。
- `git diff --stat`。
- 当前 `git diff`，排除 `.agent`、`node_modules`、`dist` 和 `target`。

不要把生产密钥、真实连接串、用户隐私数据或完整无关日志放入 deepv4 输入。
