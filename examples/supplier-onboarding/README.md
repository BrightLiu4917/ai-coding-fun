# 供应商入驻示例

这是一个端到端学习示例，用来展示 AI 全栈控制系统如何串起需求、规格、接口、任务切片、Codex 实现、测试和审查。

本示例不是业务项目默认规则。字段、状态、接口路径和权限只用于演示，真实项目必须重新确认。

## 文件关系

```mermaid
flowchart TD
  A["业务需求"] --> B["openspec/changes/add-supplier-onboarding/proposal.md"]
  B --> C["design.md"]
  C --> D["tasks.md"]
  C --> E["specs/supplier-onboarding/spec.md"]
  D --> F["api-contracts/supplier-onboarding.md"]
  F --> G["Codex 实现最小切片"]
  G --> H["tests and logs"]
  H --> I["deepv4 二审"]
  I --> J["发布审查"]
```

`openspec/changes/add-supplier-onboarding/` 是事实源；`api-contracts/supplier-onboarding.md` 只是接口契约展开文档，不能和 OpenSpec 写两套冲突规则。

## 学习顺序

1. 先读 `openspec/changes/add-supplier-onboarding/proposal.md`，看范围如何声明。
2. 再读 `design.md`，看不确定点如何保留为待确认。
3. 读 `tasks.md`，看 DBA、API、后端、前端、测试、审查如何拆分。
4. 读 `api-contracts/supplier-onboarding.md`，看接口契约如何独立于实现确认。
5. 实现完成后运行测试和 deepv4 二审。
6. 读 `review-report.md`，看发布审查如何记录阻塞问题、风险和验证结果。
7. 最后由 Codex 做 release review。

## 对应命令

```bash
bash scripts/openspec-check.sh examples/supplier-onboarding/openspec/changes/add-supplier-onboarding
bash scripts/route-compliance-check.sh examples/supplier-onboarding/openspec/changes/add-supplier-onboarding
```
