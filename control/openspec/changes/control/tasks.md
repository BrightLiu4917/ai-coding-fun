# 任务清单

## 规格确认
| 任务 | 优先级 | 状态 | 负责人 | 预计工时 | 验收标准 |
|------|--------|------|--------|----------|----------|
| 确认变更提案 | P0 | 已完成 | 产品需求工程师 | 0.5h | 项目背景、目标、范围、非目标、影响范围和风险已确认 |
| 确认目录设计 | P0 | 已完成 | 系统架构师 | 0.5h | 根目录保留文件、`control/` 迁移清单和脚本路径策略已确认 |
| 确认规格变更 | P0 | 已完成 | OpenSpec 规格工程师 | 0.5h | specs delta 只包含已确认的目录结构规则 |

## 实现任务
| 任务 | 优先级 | 状态 | 负责人 | 预计工时 | 验收标准 |
|------|--------|------|--------|----------|----------|
| 创建 `control/` 并迁移控制系统资产 | P0 | 已完成 | 系统架构师 | 1h | 指定目录和文件迁移完成，根目录仅保留已确认入口和本机文件 |
| 更新根目录 `AGENTS.md` | P0 | 已完成 | OpenSpec 规格工程师 | 1h | 根目录入口正确指向 `control/` 下事实源、规则、agent 和脚本 |
| 更新 `README.md` 和说明文档 | P0 | 已完成 | OpenSpec 规格工程师 | 1h | 目录结构、命令示例和路径说明全部更新 |
| 更新脚本路径计算逻辑 | P0 | 已完成 | 系统架构师 | 2h | 安装、检测、检查、deepv4 和测试脚本能在新目录下运行 |
| 更新 profile 和模板路径 | P0 | 已完成 | 系统架构师 | 1h | profile 清单、模板引用和示例路径与新目录一致；安装输出结构保持原语义 |
| 更新 OpenSpec 和 agent 文档路径 | P1 | 已完成 | OpenSpec 规格工程师 | 1h | `control/openspec`、`control/agents`、`control/docs` 中无错误旧路径引用 |

## 验证任务
| 任务 | 优先级 | 状态 | 负责人 | 预计工时 | 验收标准 |
|------|--------|------|--------|----------|----------|
| 文档链接检查 | P0 | 已完成 | 测试工程师 | 0.5h | `bash control/scripts/docs-link-check.sh` 通过 |
| Agent 检查 | P0 | 已完成 | 测试工程师 | 0.5h | `bash control/scripts/agent-check.sh` 通过 |
| OpenSpec 检查 | P0 | 已完成 | 测试工程师 | 0.5h | `bash control/scripts/openspec-check.sh control/openspec/changes/control` 通过 |
| OpenSpec 中文检查 | P0 | 已完成 | 测试工程师 | 0.5h | `bash control/scripts/openspec-language-check.sh control/openspec` 通过 |
| 安装 dry-run 验证 | P0 | 已完成 | 测试工程师 | 1h | 安装脚本 dry-run 输出符合预期，profile 路径有效 |
| 残留路径引用审查 | P1 | 已完成 | 发布审查工程师 | 0.5h | 旧路径引用已逐项处理，保留项有明确原因 |
| 发布审查 | P0 | 已完成 | 发布审查工程师 | 1h | 当前 diff、验证结果、风险和回滚方案已记录 |
