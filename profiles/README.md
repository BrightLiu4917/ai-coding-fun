# Profiles

profile 用来控制 `scripts/install-to-project.sh` 复制哪些控制系统文件到目标项目。

建议普通用户优先使用：

```bash
bash scripts/bootstrap-new-project.sh --project-dir /path/to/project --profile auto
```

`auto` 会通过 `scripts/detect-project-profile.sh` 识别项目并推荐具体 profile。

## 格式

每个 profile 位于：

```text
profiles/<profile-name>/profile.toml
```

当前安装脚本只解析 `items = [...]` 和 `exclude_items = [...]`，这是刻意保持的简单 TOML 子集，避免引入新依赖。

```toml
name = "default"
description = "完整安装"
items = [
  "AGENTS.md",
  "CODEX_TASK_TEMPLATE.md",
  "openspec",
  "docs",
  "agents",
  "scripts",
  "templates",
  "profiles",
  "CONTEXT.md",
  "CONTEXT-MAP.md"
]
```

## 使用

```bash
bash scripts/bootstrap-new-project.sh --project-dir /path/to/project --profile auto
bash scripts/install-to-project.sh --dry-run --profile default /path/to/project
bash scripts/install-to-project.sh --dry-run --profile fullstack-admin /path/to/project
bash scripts/install-to-project.sh --backup --profile minimal /path/to/project
bash scripts/install-to-project.sh --backup --profile gupo /path/to/gupo-project
bash scripts/install-to-project.sh --only AGENTS.md --only docs --only agents /path/to/project
```

## 内置 profile

| profile | 适合项目 |
|---------|----------|
| `fullstack-admin` | Spring Boot + Vue/React 后台系统，包含全栈和供应商入驻示例 |
| `java-springboot` | Java / Spring Boot 后端，包含 Spring Boot + MyBatis 示例 |
| `vue3-admin` | Vue3 管理端 |
| `react-admin` | React 管理端 |
| `go-gin` | Go / Gin 后端 |
| `php` | PHP / Laravel / ThinkPHP 后端 |
| `minimal` | 最小 OpenSpec、agent、docs、templates |
| `default` | 通用完整安装 |
| `gupo` | 仅 gupo 专用项目 |

## 约束

- `items` 必须是仓库内相对路径。
- `exclude_items` 可排除文件或目录；匹配目录时会排除其子路径。
- 禁止使用绝对路径或 `..`。
- 默认安装遇到冲突会失败。
- 需要覆盖时显式使用 `--force`。
- 需要保留目标文件备份时使用 `--backup`。
- `default` 安装通用控制系统资产和 `agents/`。
- 新项目建议先用 `auto` 识别，再按推荐 profile 安装。
- gupo 项目使用 `profiles/gupo/profile.toml`。
