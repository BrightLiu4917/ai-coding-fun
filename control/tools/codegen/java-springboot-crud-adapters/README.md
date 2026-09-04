# Java Spring Boot CRUD Adapter

本目录存放 Java Spring Boot CRUD 代码生成 adapter。

控制系统本身不假设存在通用脚手架。代码生成必须先选择 adapter，再在 adapter 内根据 Spring Boot 版本选择脚本。

## 判定优先级

1. 用户显式指定 adapter。
2. 目标项目 `.agent/codegen.toml` 声明 adapter。
3. 安装 profile 或 adapter registry 声明 adapter。
4. 项目指纹高置信命中 adapter。
5. 无法确认时停止询问。

## 当前状态

| Adapter | 状态 | 说明 |
|---------|------|------|
| `gupo` | available | 仅适用于 gupo 项目封装和目录约定 |
| `generic` | preview-only | 只生成审查用预览包，不直接写入业务源码目录；落地前仍需用户确认后由后端实现流程处理 |

## 目标项目配置

推荐目标项目显式声明：

```toml
# .agent/codegen.toml
[java.springboot.crud]
adapter = "gupo"
```

没有明确 adapter 时，禁止用 gupo 脚手架试生成。

## 通用预览 Adapter

通用 adapter 当前只作为预览工具：

```bash
bash .ai-control/control/tools/codegen/java-springboot-crud-adapters/generic/scripts/crud-preview --help
```

它的输出位置默认为 `.agent/codegen-preview/<EntityName>/`，用于审查待生成文件、字段和层次结构。它不得绕过 OpenSpec、数据库工程师、API 契约工程师、用户确认和代码审查，也不得直接覆盖 `src/main`。

如果目标项目不是 gupo，且需要真实落地 CRUD：
- 先用 generic preview adapter 形成可审查草稿，或跳过预览直接进入人工实现流程。
- 经用户确认后转入 开发工程师（`agent-dev`）做生产级实现。
- 手写实现必须遵守 `.ai-control/control/rules/41-spring-boot.md` 和 `.ai-control/control/rules/40-backend.md` 的抽象、封装、事务、契约、测试和审查要求。
