# 改进记录

时间：2026-08-19。以下为本轮系统性改进的完整记录，按主题分组。

## 一、Bug 修复（阶段 0）

| 问题 | 修复 |
|---|---|
| rbac-check 读错 project.env 路径，权限门禁永远空转 | 后随 RBAC 校验功能整体移除 |
| check-project-ready 用错根目录变量，mvnw 检测必然落空；检查脚本有写副作用 | 改用 `PROJECT_ROOT`；自动 `--write` 改为提示 |
| run-deepv4-review 未切到项目根即执行相对路径命令；变量无引号展开 | 先 `cd "$PROJECT_ROOT"`；输入文件走位置参数 |
| detect-project-profile `--write` 整体重写 env，覆盖用户手改值；单引号值破坏文件 | 合并式更新（已有非空值保留）；`sq` 单引号转义，往返一致 |
| bootstrap/setup 无条件 `--force`，静默覆盖用户的 project.md/CONTEXT.md | bootstrap 仅显式 `--force` 才覆盖；setup 交互确认 + 覆盖前备份 |
| openspec-language-check 用裸 `/tmp` 临时文件 | mktemp + trap |

## 二、安全加固（阶段 1）

- deepv4 外发 diff：新增敏感文件排除（.env、密钥、生产配置）、密钥模式扫描（命中即中止，`DEEPV4_ALLOW_SECRETS=1` 显式放行）、512KB 体积截断。
- API key 从 curl 命令行移入 mktemp header 文件（chmod 600 + trap 清理），不再被 `ps` 可见。
- 所有写 deepv4.env 的路径统一 `chmod 600`；`.gitignore` 追加先于密钥写入。

## 三、文档去重与结构（阶段 2）

- agent-dba 与 DB_SCHEMA_RULES 逐字重复的两大章节收敛为引用，RULES 为唯一权威。
- 三份同构的"精准修改"章节抽为 `control/docs/CODE_CHANGE_RULES.md`，java/web/architect 只留栈特有补充；go/php 同步纳入。
- 根 AGENTS.md 改由 `sync-agents-md.sh` 从 `control/AGENTS.md` 生成（映射经逐字节验证无损），agent-check 校验同步。
- docs/common/README 修正名不副实的描述。
- AGENTS.md 数据安全章节明确"红线摘要在契约、细则例外在 RULES"分工，措辞对齐。
- 15 个 agent 手册补齐 AGENT_BASE 规定的"停止并询问"章节（角色特有触发条件），agent-check 强制校验。

## 四、检查实质化（阶段 3）

- **sql-safety-check 重写**：从 5 条单行 grep 升级为语句级分析（剥离注释/字符串 → 按分号重组 → 逐句判定，报错带行号）。修复跨行漏检、注释误报、"所有 UPDATE 无条件报错"三个问题；新增无 ON/USING 的 JOIN 检测。
- **RBAC 校验功能移除**（按用户决定）：删除 rbac-check.sh 及 openspec-check 调用；RBAC_RULES.md 实现规则文档与 ACCESS_CONTROL_MODE 元数据保留。
- **bats 测试体系**：`control/tests/` 共 59 个用例，覆盖全部修复的回归、安装安全、外发防护、OpenSpec 检查链、用例同步、适配导出、ai 入口。统一入口 `run-control-tests.sh`。
- **CI**：本仓库 `.github/workflows/ci.yml`（shell 语法 + shellcheck / 五项自检 / bats 三个 job）；目标项目 CI 模板修复 glob 展开问题。

## 五、测试用例前置工作流（新增能力）

- change 骨架新增第五件套 `test-cases.md`（模板 + ai-dev 骨架生成）；孤儿模板 test-plan.md 并入后删除。
- AGENTS.md："编码前必须确认"加入验收测试用例；用例为验收契约，执行阶段禁止为迁就实现修改。
- 路由流程改为测试工程师两次介入：设计期写用例（随 change 确认）→ 实现后按用例执行回填。
- 新增 `test-cases-check.sh`（存在性 + 闭环：affected_apis⇒异常流用例、affected_pages⇒权限/空态/错误态用例；`--require-filled` 发布门禁禁止"已设计"残留），挂入 openspec-check。
- 新增 `test-cases-sync.sh`：解析 JUnit XML，按测试名中的用例 ID（TC-01 变体均可）自动回填状态为通过/失败；手动用例不自动回填；run-tests.sh 以 trap 串接（失败也回填）。
- agent-test 改写为两阶段职责；agent-release 必查项加用例回填检查。
- examples 三个示例 change 补齐贴合各自影响范围的用例文件。

## 六、多工具适配（新增能力）

- 新增 `export-adapters.sh`，从单一源生成 35 个适配产物：
  - `CLAUDE.md`（@AGENTS.md import，Claude Code 契约自动加载）；
  - `.claude/agents/` × 15（frontmatter description 自动提炼 + use proactively，Claude 原生自动委派）；
  - `.claude/skills/` × 3（openspec-feature / openspec-ready / release-review，描述含口语触发词）；
  - `workbuddy-skills/` × 16（总契约 + 15 角色，SKILL.md 格式）。
- Codex / Kimi / Cursor 原生读 AGENTS.md，无需导出。幂等（默认不覆盖，`--force` 重生成）；bootstrap 安装时自动执行。

## 七、易用性（新增能力）

- **lite 小需求快速通道**：`feature <id> --lite` 只生成 proposal/tasks/test-cases 三个轻量文件；proposal 标注 `变更级别: lite`；impact-check 门禁强制拦截声明了数据库/API 影响的 lite 变更（防偷渡）；分级条件写入 AGENTS.md。
- **`./ai` 统一命令入口**（模板 `control/templates/ai-launcher.sh`，安装时生成到项目根）：
  - `ai new / check / test / ship / sync / doctor` 六个动词替代长路径命令；
  - `ai install-cli` 安装全局寻路壳到 `~/.local/bin`（向上找项目转发，多项目安全，不碰系统目录）。
- **自然语言意图路由**（AGENTS.md 新章节）：人话→动作对照表；判级必须基于影响探测证据（触碰哪些文件/表/接口）而非措辞猜测；确认单必须标注"级别 + 判级理由"；用户明说小/大需求时尊重但门禁照常；拿不准判高一级。

## 八、文档重写

- README.md 全面重写：核心特性、30 秒上手、两个确认点、工作流图、多工具接入表、安装/检查/文档索引，与当前功能完全对齐。
- 使用手册.md 全面重写为详细指南：三种使用方式（自然语言/./ai/底层脚本）、lite 与完整流程分节详解、数据库两阶段确认、测试用例机制详解（命名约定/自动回填/门禁）、deepv4 配置与外发安全、完整命令参考表、目录结构说明、常见问题 7 则。

## 九、独立二审重构（去 deepv4 化）

- **全面改名**：deepv4 → 独立二审（review）。脚本 `prepare-review.sh` / `run-review.sh` / `providers/openai-compatible.sh`，配置 `.agent/review.env` + `REVIEW_*` 变量，文档 `SECOND_REVIEW.md` / `二审使用说明.md`。旧 `DEEPV4_*` 变量、旧 `deepv4.env`、`--deepv4` 参数全部兼容可用；历史归档（openspec/changes）不改写。
- **分级触发**：`REVIEW_MODE=auto|always|never`（默认 auto）；auto 下 lite 变更自动跳过二审并记录到 `review-skip.log`。
- **定向审查**：prepare 按 change 影响范围裁剪审查问题——碰表追问锁表/迁移/回滚，碰接口追问兼容性/异常路径，碰页面追问状态覆盖，不再六问全撒网。
- **VERDICT 门禁**：二审输出末尾必须给出 `VERDICT: PASS|PASS_WITH_RISKS|BLOCK` 机读结论；BLOCK 直接拦截 ship；缺失按旧格式放行并告警。
- **skip-review 留痕**：`ai ship <id> --skip-review "原因"` 可显式跳过二审但必须给原因并落档；无原因拒绝执行；用例回填门禁不随二审跳过。
- **失败分类处理**：401/402/403（key 错/欠费/无权限）不重试、立刻报错并给修复提示；网络超时/429/5xx 重试一次；未配置直接跳过。
- **provider 可插拔**：新增 `providers/anthropic.sh`（Claude 官方 Messages API），`REVIEW_PROVIDER=openai-compatible|anthropic` 切换；任何 OpenAI 兼容端点改 `review.env` 三行即可换模型。
- 新增 `review-flow.bats` 9 个用例（跳过/分级/VERDICT/兼容/留痕），总测试数 59 → 68。

## 十、结构重组与平台化（v1.0.0 收官批次）

- **rules 目录扁平化**：`docs/` 下 20+ 份 RULES 及 `stacks/`、`features/`、`common/` 子目录全部移入 `control/rules/`，单层编号命名（00-agent-base、01-code-change、10-db-schema、20-api、31-vue3、41-spring-boot……），索引见 `rules/README.md`；`docs/` 只留给人读的中文文档、ADR 和系统说明；全仓库引用同步更新，profiles 增加 rules 安装项。
- **角色合并 15→6**（用户拍板提前执行）：`agent-spec`（产品+OpenSpec+API 契约）、`agent-architect`、`agent-dba`、`agent-dev`（Java/Go/PHP/Web/UI/codegen，按栈分章节）、`agent-test`（两阶段）、`agent-release`（并入安全/性能必查项）。原 15 份手册内容全部并入对应章节，无删减；AGENTS.md、路由、适配导出、检查器、测试联动更新。
- **版本化升级**：新增 `control/VERSION`（1.0.0）+ `upgrade-control.sh` + `ai upgrade` 命令。只更新框架文件（`.ai-control/control/`、根 AGENTS.md、`./ai`），绝不触碰 openspec/、CONTEXT.md、project.env、.agent/；升级前自动备份到 `.agent/install-backup/upgrade-<时间戳>/` 可回退；安装时记录版本与来源（`AI_CONTROL_SOURCE`）。
- **规格防漂移**：新增 `spec-drift-check.sh`——从 change/spec 声明的 API 路径和 affected_tables 反向比对代码与迁移文件，报告"声明了但代码里找不到"的漂移；`ai ship` 时自动以警告模式运行，`--strict` 可作硬门禁。
- **文档同步**：README 全面重写（30 秒上手、两个确认点、工作流图、多工具接入表、6 角色表）；使用手册重写为 `./ai` 命令体系；docs-link-check 跳过 openspec/changes 历史归档（不改历史）。
- 新增 upgrade.bats（5 用例）、spec-drift.bats（4 用例），总测试数 68 → 77。

## 十一、CLI 二审 provider

- 新增 `providers/claude-cli.sh`（`claude -p` 无头模式，材料走 stdin 防超长）和 `providers/codex-cli.sh`（`codex exec`，让 codex 读取输入文件防参数超限）；复用订阅免 API key，每次全新会话保证二审独立性。
- `run-review.sh` 的"已配置"判断增加 CLI 型 provider（无需 API 变量）。
- 二审接法达到四种 + WorkBuddy 手动通道；`二审使用说明.md`、使用手册、review.env.example 同步。
- 新增 cli-providers.bats（5 用例，stub 假 CLI 不依赖真实安装），总测试数 77 → 82。

## 十二、去 Codex 中心化

- 原项目所有把 Codex 当"主 AI 代称"的措辞全部中性化为"AI 助手"（文档、脚本输出、任务模板、agent 手册、流程图、示例）；Codex 作为具体产品的引用（多工具对照表、codex-cli provider、AGENTS.md 自动发现说明）保留。
- 文件改名：`Codex如何提需求.md` → `如何提需求.md`、`CODEX_TASK_TEMPLATE.md` → `TASK_TEMPLATE.md`，全部引用同步。
- 顺带修复角色合并的两处机械替换残留：AGENT_ROUTING.md 按 6 角色重写（清除重复条目）、agent-release.md 结构修复（输出格式章节归位）。

## 十三、WorkBuddy 实机验证与自包含增强

- 实机对照本机 WorkBuddy 官方市场技能，修正 tags 格式（YAML 列表 → 逗号字符串）。
- 实机验证通过：WorkBuddy 正确执行 agent-dba 两阶段确认流程（先设计审查、承诺不执行 SQL）。
- 自包含增强：WorkBuddy 技能导出时将各角色引用的 rules 全文内嵌为附录快照，空工作区也有完整约束；Claude/Codex 等项目内工具保持引用式不受影响；快照更新提示写入技能正文。
- 新增自包含断言用例，总测试数 82 → 83。

## 验证状态

- bats：83/83 通过（`bash control/scripts/run-control-tests.sh`）
- 自检：agent-check（6 agents）、route-check、docs-link-check、AGENTS.md 同步、OpenSpec 冲突检查全部通过
- 全部 shell 脚本 `bash -n` 语法通过；shellcheck 本地 0 告警（.shellcheckrc 豁免中文引号误报，死变量已清理）

## 已决定不做 / 暂缓

- RBAC 结构化校验：随 RBAC 校验功能一并移除（用户决定）
- 8 篇中文文档合并为单一 GUIDE：README 与使用手册已重写覆盖主流程，其余文档保留备查，暂不合并
- Qoder/通义等更多工具适配：等用户确认具体工具后按 export-adapters 模式追加
