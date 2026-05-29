# deepv4 二审使用说明

## 定位

deepv4 只做二审，不直接写代码，不决定业务规则。

推荐分工：

```text
Codex：需求、OpenSpec、架构、实现、测试、最终校验
deepv4：审查 diff、测试结果、SQL、权限、安全、边界和遗漏
Codex：判断 deepv4 意见是否成立，并修复真实问题
```

## 配置

小白优先使用初始化命令配置：

```bash
bash scripts/ai-dev.sh init
```

当脚本询问是否启用 deepv4 时选择启用，然后输入：

```text
DEEPV4_BASE_URL
DEEPV4_API_KEY
DEEPV4_MODEL
```

脚本会生成 `.agent/deepv4.env`。

高级用户也可以手动配置。

在目标项目创建：

```text
.agent/deepv4.env
```

可以从模板复制：

```bash
cp templates/deepv4.env.example .agent/deepv4.env
```

填写：

```bash
DEEPV4_BASE_URL='https://api.example.com/v1'
DEEPV4_API_KEY='replace-with-your-key'
DEEPV4_MODEL='deepv4'
DEEPV4_REVIEW_COMMAND='bash scripts/providers/deepv4-openai-compatible.sh'
```

真实 key 不要提交。

## 审查流程

实现和测试后执行：

```bash
bash scripts/prepare-deepv4-review.sh
bash scripts/run-deepv4-review.sh
```

输出文件：

```text
.agent/reviews/deepv4-input.md
.agent/reviews/deepv4-output.md
```

## 卡住时怎么判断

如果终端停在：

```text
DEEPV4_HTTP_REQUEST: ...
```

通常是模型响应慢、网络慢或 API 没有返回。可以另开终端看输出文件是否增长：

```bash
tail -f .agent/reviews/deepv4-output.md
```

## Codex 最终处理

deepv4 输出后，在 Codex 里说：

```text
读取 .agent/reviews/deepv4-output.md，判断哪些问题成立。
成立的问题请修复并跑测试；不成立的问题说明原因。
```

## 注意

- deepv4 结果不是业务事实。
- deepv4 不能替代 OpenSpec。
- deepv4 不能替代测试。
- 所有修复仍由 Codex 按项目规则和用户确认执行。
