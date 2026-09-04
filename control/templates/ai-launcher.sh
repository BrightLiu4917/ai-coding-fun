#!/usr/bin/env bash
set -euo pipefail

# ai —— 控制系统统一命令入口（薄壳，只做转发）
#
#   ai new <id> [--lite]   创建变更骨架（--lite 小需求快速通道）
#   ai check <id>          校验 change 是否可请求用户确认
#   ai test [<id>]         跑测试；带 <id> 时自动回填该 change 的用例状态
#   ai ship <id> [--skip-review "原因"]  发布门禁：用例回填检查 + 独立二审（跳过必须留痕）
#   ai sync                重新生成所有 AI 工具适配文件
#   ai doctor              环境体检
#   ai upgrade [--source <控制系统仓库>]  升级框架文件（不碰用户数据，升级前自动备份）
#   ai install-cli         安装全局 ai 命令到 ~/.local/bin（免 ./ 前缀）
#
# 本文件由控制系统安装时生成；升级时可用 --force 重新生成。

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMD="${1:-help}"
shift || true

# help 不依赖控制系统存在
if [[ "$CMD" == "help" || "$CMD" == "--help" || "$CMD" == "-h" ]]; then
  sed -n '5,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
fi

# 定位控制系统脚本目录：安装布局优先，仓库布局兜底
if [[ -d "$SELF_DIR/.ai-control/control/scripts" ]]; then
  SCRIPTS="$SELF_DIR/.ai-control/control/scripts"
elif [[ -d "$SELF_DIR/control/scripts" ]]; then
  SCRIPTS="$SELF_DIR/control/scripts"
else
  echo "未找到控制系统（.ai-control/control/scripts 或 control/scripts）" >&2
  exit 1
fi

case "$CMD" in
  new)
    exec bash "$SCRIPTS/ai-dev.sh" feature "$@"
    ;;
  check)
    exec bash "$SCRIPTS/ai-dev.sh" ready "$@"
    ;;
  test)
    if [[ "$#" -ge 1 && "${1#-}" == "$1" ]]; then
      change_id="$1"
      shift
      OPENSPEC_CHANGE_ID="$change_id" exec bash "$SCRIPTS/run-tests.sh" "$@"
    fi
    exec bash "$SCRIPTS/run-tests.sh" "$@"
    ;;
  ship)
    change_id=""
    skip_reason=""
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --skip-review)
          skip_reason="${2:-}"
          if [[ -z "$skip_reason" ]]; then
            echo "用法: ai ship <change-id> --skip-review \"原因\"（跳过必须留痕）" >&2
            exit 1
          fi
          shift 2
          ;;
        *)
          change_id="$1"
          shift
          ;;
      esac
    done
    if [[ -z "$change_id" ]]; then
      echo "用法: ai ship <change-id> [--skip-review \"原因\"]" >&2
      exit 1
    fi
    change_dir="$SELF_DIR/openspec/changes/$change_id"
    if [[ -d "$change_dir" && -x "$SCRIPTS/test-cases-check.sh" ]]; then
      bash "$SCRIPTS/test-cases-check.sh" --require-filled "$change_dir"
    fi
    if [[ -d "$change_dir" && -x "$SCRIPTS/spec-drift-check.sh" ]]; then
      bash "$SCRIPTS/spec-drift-check.sh" "$change_dir" "$SELF_DIR" || true
    fi
    if [[ -n "$skip_reason" ]]; then
      mkdir -p "$SELF_DIR/.agent/reviews"
      printf '%s\t%s\tSKIPPED_BY_USER: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$change_id" "$skip_reason" \
        >> "$SELF_DIR/.agent/reviews/review-skip.log"
      echo "已跳过独立二审并留痕: $skip_reason"
      exit 0
    fi
    OPENSPEC_CHANGE_ID="$change_id" exec bash "$SCRIPTS/ai-dev.sh" review
    ;;
  sync)
    if [[ -x "$SCRIPTS/export-adapters.sh" ]]; then
      bash "$SCRIPTS/export-adapters.sh" --force "$SELF_DIR"
    fi
    if [[ -x "$SCRIPTS/sync-agents-md.sh" && -f "$SCRIPTS/../AGENTS.md" ]]; then
      bash "$SCRIPTS/sync-agents-md.sh"
    fi
    ;;
  doctor)
    exec bash "$SCRIPTS/check-project-ready.sh" "$@"
    ;;
  upgrade)
    exec bash "$SCRIPTS/upgrade-control.sh" "$@"
    ;;
  install-cli)
    BIN_DIR="${AI_CLI_BIN_DIR:-$HOME/.local/bin}"
    mkdir -p "$BIN_DIR"
    cat > "$BIN_DIR/ai" <<'SHIM'
#!/usr/bin/env bash
# ai 全局寻路壳：向上查找最近的项目级 ai 入口并转发
set -euo pipefail
dir="$PWD"
while [[ "$dir" != "/" ]]; do
  if [[ -x "$dir/ai" && "$dir/ai" != "${BASH_SOURCE[0]}" ]]; then
    exec "$dir/ai" "$@"
  fi
  if [[ -d "$dir/.ai-control" && -x "$dir/.ai-control/control/scripts/ai-dev.sh" ]]; then
    exec bash "$dir/.ai-control/control/scripts/ai-dev.sh" "$@"
  fi
  dir="$(dirname "$dir")"
done
echo "当前目录不在任何控制系统项目内（未找到 ./ai 或 .ai-control/）" >&2
exit 1
SHIM
    chmod +x "$BIN_DIR/ai"
    echo "已安装: $BIN_DIR/ai"
    case ":$PATH:" in
      *":$BIN_DIR:"*) ;;
      *)
        echo "注意: $BIN_DIR 不在 PATH 中。请在 shell 配置中加入："
        echo "  export PATH=\"$BIN_DIR:\$PATH\""
        ;;
    esac
    ;;
  *)
    echo "未知命令: $CMD（ai help 查看用法）" >&2
    exit 1
    ;;
esac
