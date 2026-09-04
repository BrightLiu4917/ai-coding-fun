#!/usr/bin/env bash
set -euo pipefail

# 控制系统升级：把源仓库的新版 control/ 框架文件更新到当前已安装项目。
#
# 只更新框架资产（.ai-control/control/、根 AGENTS.md、./ai 入口），
# 绝不触碰用户数据：openspec/、CONTEXT.md、CONTEXT-MAP.md、
# .ai-control/project.env、.agent/（含 review.env、日志、审查记录）。
#
# 升级前整体备份到 .agent/install-backup/upgrade-<时间戳>/，可随时回退。
#
# 用法：
#   upgrade-control.sh --source /path/to/控制系统仓库 [project-root]
#   源也可来自环境变量 AI_CONTROL_SOURCE 或 project.env 中记录的安装来源。

SOURCE=""
TARGET_ROOT=""
for arg in "$@"; do
  case "$arg" in
    --source)   EXPECT_SOURCE=1 ;;
    *)
      if [[ "${EXPECT_SOURCE:-0}" -eq 1 ]]; then
        SOURCE="$arg"
        EXPECT_SOURCE=0
      else
        TARGET_ROOT="$arg"
      fi
      ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
fi
[[ -n "$TARGET_ROOT" ]] && PROJECT_ROOT="$(cd "$TARGET_ROOT" && pwd)"

INSTALLED_CONTROL="$PROJECT_ROOT/.ai-control/control"
if [[ ! -d "$INSTALLED_CONTROL" ]]; then
  echo "当前项目未安装控制系统（缺少 .ai-control/control/）" >&2
  exit 1
fi

# 解析源：参数 > 环境变量 > project.env 记录
if [[ -z "$SOURCE" ]]; then
  SOURCE="${AI_CONTROL_SOURCE:-}"
fi
if [[ -z "$SOURCE" && -f "$PROJECT_ROOT/.ai-control/project.env" ]]; then
  SOURCE="$(
    set +eu
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/.ai-control/project.env" >/dev/null 2>&1
    printf '%s' "${AI_CONTROL_SOURCE:-}"
  )"
fi
if [[ -z "$SOURCE" || ! -d "$SOURCE/control" ]]; then
  echo "未找到升级源。请指定：upgrade-control.sh --source /path/to/控制系统仓库" >&2
  exit 1
fi
SOURCE="$(cd "$SOURCE" && pwd)"

current_version="unknown"
[[ -f "$PROJECT_ROOT/.ai-control/VERSION" ]] && current_version="$(cat "$PROJECT_ROOT/.ai-control/VERSION")"
new_version="unknown"
[[ -f "$SOURCE/control/VERSION" ]] && new_version="$(cat "$SOURCE/control/VERSION")"

echo "当前版本: $current_version -> 目标版本: $new_version"
echo "升级源: $SOURCE"

if [[ "$current_version" == "$new_version" && "$current_version" != "unknown" ]]; then
  echo "版本相同，无需升级。"
  exit 0
fi

# 1. 备份
STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="$PROJECT_ROOT/.agent/install-backup/upgrade-$STAMP"
mkdir -p "$BACKUP_DIR"
cp -R "$INSTALLED_CONTROL" "$BACKUP_DIR/control"
[[ -f "$PROJECT_ROOT/AGENTS.md" ]] && cp "$PROJECT_ROOT/AGENTS.md" "$BACKUP_DIR/AGENTS.md"
[[ -f "$PROJECT_ROOT/ai" ]] && cp "$PROJECT_ROOT/ai" "$BACKUP_DIR/ai"
echo "已备份到: ${BACKUP_DIR#$PROJECT_ROOT/}"

# 2. 替换框架目录（control/ 内只有框架资产，用户数据不在其中）
rm -rf "$INSTALLED_CONTROL"
cp -R "$SOURCE/control" "$INSTALLED_CONTROL"

# 3. 更新根 AGENTS.md 与 ./ai 入口
cp "$SOURCE/control/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
if [[ -f "$SOURCE/control/templates/ai-launcher.sh" ]]; then
  cp "$SOURCE/control/templates/ai-launcher.sh" "$PROJECT_ROOT/ai"
  chmod +x "$PROJECT_ROOT/ai"
fi

# 4. 记录版本与来源
printf '%s\n' "$new_version" > "$PROJECT_ROOT/.ai-control/VERSION"
if [[ -f "$PROJECT_ROOT/.ai-control/project.env" ]] && ! grep -q '^AI_CONTROL_SOURCE=' "$PROJECT_ROOT/.ai-control/project.env"; then
  printf "AI_CONTROL_SOURCE='%s'\n" "$SOURCE" >> "$PROJECT_ROOT/.ai-control/project.env"
fi

# 5. 重新生成适配层（不覆盖用户手改的文件）
if [[ -x "$INSTALLED_CONTROL/scripts/export-adapters.sh" ]]; then
  bash "$INSTALLED_CONTROL/scripts/export-adapters.sh" "$PROJECT_ROOT" || true
fi

echo "UPGRADE_OK: $current_version -> $new_version"
echo "用户数据未触碰：openspec/、CONTEXT.md、project.env、.agent/。"
echo "如需回退：cp -R ${BACKUP_DIR#$PROJECT_ROOT/}/control .ai-control/control"
