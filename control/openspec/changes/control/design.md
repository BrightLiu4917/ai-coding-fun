# 设计说明：控制系统仓库目录收敛

## 系统架构

本变更将仓库划分为根目录入口层和控制系统资产层：

```text
.
├── AGENTS.md
├── README.md
├── control/
│   ├── CONTEXT.md
│   ├── CONTEXT-MAP.md
│   ├── CODEX_TASK_TEMPLATE.md
│   ├── openspec/
│   ├── agents/
│   ├── docs/
│   ├── scripts/
│   ├── templates/
│   ├── profiles/
│   ├── tools/
│   └── examples/
├── .agent/
├── .gitignore
└── .git/
```

根目录 `AGENTS.md` 继续作为 Codex 全局入口，但其事实源路径需要改为 `control/openspec/`、`control/docs/`、`control/agents/` 等。根目录 `README.md` 继续作为人工入口，并说明控制系统资产位于 `control/`。

## 模块设计

- 入口模块：根目录 `AGENTS.md` 和 `README.md`。
- 规格模块：`control/openspec/`。
- 上下文模块：`control/CONTEXT.md` 和 `control/CONTEXT-MAP.md`。
- 规则模块：`control/docs/`。
- 角色模块：`control/agents/`。
- 自动化模块：`control/scripts/`。
- 模板模块：`control/templates/`。
- 安装组合模块：`control/profiles/`。
- 确定性工具模块：`control/tools/`。
- 示例模块：`control/examples/`。

## 流程设计

```text
用户打开仓库
-> 阅读根目录 README.md
-> Codex 读取根目录 AGENTS.md
-> AGENTS.md 指向 control/ 下事实源
-> Codex 按 control/openspec、control/docs、control/agents 执行任务
-> 脚本通过自身位置定位 control/ 和仓库根目录
-> 检查脚本验证文档链接、agent、OpenSpec 和安装逻辑
```

## 产品和交互

- 用户流程：用户仍从根目录 `README.md` 和 `AGENTS.md` 进入，不需要先理解全部控制系统目录。
- 状态设计：不涉及运行时状态。
- 异常流程：如果脚本找不到 `control/`，应输出明确错误并停止。

## 接口设计

- 路径：不涉及运行时 API。
- 请求：不涉及运行时请求。
- 响应：不涉及运行时响应。
- 兼容性：Shell 脚本命令入口可能从 `scripts/*.sh` 变为 `control/scripts/*.sh`，README 和文档必须同步说明。

## 数据库设计

- 表：不涉及数据库表。
- 字段：不涉及字段。
- 索引：不涉及索引。
- 迁移：不涉及数据库迁移。
- 回滚：不涉及数据库回滚。

## 技术选型

- 继续使用 Bash、Markdown 和简单 TOML 子集。
- 不引入新依赖。
- 脚本应通过 `BASH_SOURCE[0]` 计算自身目录，避免依赖调用时的当前工作目录。

## 性能设计

本变更不涉及运行时性能。检查脚本应继续使用 `rg`、`find`、`bash` 等轻量工具，避免引入慢速全仓扫描。

## 扩展性设计

- `control/` 作为控制系统资产根目录，后续可支持打包、版本化发布或 skill 提取。
- 根目录入口保持稳定，避免未来每次资产目录内部调整都影响 Codex 发现入口。

## 安全设计

- `.agent/` 继续作为本机密钥、日志和 deepv4 产物目录，默认不提交。
- `control/` 内不得放入密钥、token、private key 或生产连接串。
- 迁移过程中不得改变 `.gitignore` 对 `.agent/` 的保护规则。

## 访问控制

- 访问控制模式：不适用。
- 本服务是否建设 RBAC：不适用。
- 责任系统：不涉及运行时权限系统。
- 允许主体或角色：不涉及。
- 权限码或权限点：不涉及。
- 菜单权限，如适用：不涉及。
- 按钮权限，如适用：不涉及。
- 无权限处理：不涉及。
- 越权处理：不涉及。
- 数据范围：不涉及。

## 验证方案

- 运行 `bash control/scripts/agent-check.sh`。
- 运行 `bash control/scripts/docs-link-check.sh`。
- 运行 `bash control/scripts/openspec-check.sh control/openspec/changes/control`。
- 运行 `bash control/scripts/openspec-language-check.sh control/openspec`。
- 运行 `bash control/scripts/route-check.sh`。
- 运行安装 dry-run，验证 profile 路径和复制清单。
- 使用 `rg` 检查残留旧路径引用，并逐项判断是否需要保留。

## 影响范围

```yaml
affected_files:
  - AGENTS.md
  - README.md
  - CONTEXT.md
  - CONTEXT-MAP.md
  - CODEX_TASK_TEMPLATE.md
  - openspec
  - agents
  - docs
  - scripts
  - templates
  - profiles
  - tools
  - examples
affected_tables:
  - none
affected_apis:
  - none
affected_pages:
  - none
affected_agents:
  - agent-openspec
  - agent-architect
  - agent-release
```

## 后端

- 受影响模块：不涉及后端运行时代码。
- 事务边界：不涉及。
- 权限和租户：不涉及。

## 前端

- 页面：不涉及。
- 组件：不涉及。
- 状态：不涉及。

## 备选方案

- 方案：保持现有根目录展开结构。
- 取舍：实现成本最低，但不能解决用户反馈的根目录文件过多问题。
- 方案：把所有文件包含 `README.md` 也迁入 `control/`。
- 取舍：根目录最干净，但人工入口不明显。
- 方案：使用 `.ai-control/` 作为仓库本体资产目录。
- 取舍：与目标业务项目画像目录语义冲突，容易混淆。

## 回滚方案

- 通过 git 回滚文件移动和路径修改。
- 如果已部分迁移失败，先恢复根目录 `AGENTS.md`、`README.md`、`openspec/`、`agents/`、`docs/`、`scripts/`、`templates/`、`profiles/`、`tools/`、`examples/`。
- 回滚后运行原路径检查脚本确认仓库可用。
