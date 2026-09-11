#!/usr/bin/env bash
set -euo pipefail

# ai —— 控制系统统一命令入口（薄壳，只做转发）
#
#   ai new <id> [--lite]   创建变更骨架（--lite 小需求快速通道）
#   ai check <id>          校验 change 是否可请求用户确认
#   ai test [<id>]         跑测试；JUnit 报告即验收证据（测试名带 TC-ID）
#   ai ship <id> [--review]  发布门禁：JUnit 证据 + 防漂移（二审默认不跑，--review 或 REVIEW_MODE=always 才跑）
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
    run_review=0
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --review)
          run_review=1
          shift
          ;;
        *)
          change_id="$1"
          shift
          ;;
      esac
    done
    if [[ -z "$change_id" ]]; then
      echo "用法: ai ship <change-id> [--review]" >&2
      exit 1
    fi
    change_dir="$SELF_DIR/openspec/changes/$change_id"
    # 脚本门禁：用例证据（JUnit 报告直查）+ 规格防漂移
    if [[ -d "$change_dir" && -x "$SCRIPTS/test-cases-check.sh" ]]; then
      bash "$SCRIPTS/test-cases-check.sh" --evidence "$change_dir"
    fi
    if [[ -d "$change_dir" && -x "$SCRIPTS/spec-drift-check.sh" ]]; then
      bash "$SCRIPTS/spec-drift-check.sh" "$change_dir" "$SELF_DIR" || true
    fi
    # 独立二审默认不跑（按需外援）；REVIEW_MODE=always 时强制跑
    review_mode=""
    for env_file in "$SELF_DIR/.agent/review.env" "$SELF_DIR/.agent/deepv4.env"; do
      [[ -f "$env_file" ]] && review_mode="$(grep -E '^REVIEW_MODE=' "$env_file" | tail -1 | cut -d= -f2- | tr -d "'\"")" && break
    done
    if [[ "$run_review" -eq 1 || "$review_mode" == "always" ]]; then
      # 主动触发（--review）必须无条件执行，覆盖 REVIEW_MODE=auto 的 lite 跳过逻辑
      forced=0
      [[ "$run_review" -eq 1 ]] && forced=1
      OPENSPEC_CHANGE_ID="$change_id" REVIEW_FORCED="$forced" exec bash "$SCRIPTS/ai-dev.sh" review
    fi
    # 高风险提示：碰表/权限/支付建议主动二审（affected_tables 用精确的 yaml 段判定）
    touches_tables=0
    if [[ -f "$change_dir/proposal.md" ]]; then
      if awk '
        /^[[:space:]]*affected_tables:/ { in_key=1; next }
        in_key && /^[[:space:]]*[a-zA-Z_]+:/ { in_key=0 }
        in_key && /^[[:space:]]*-[[:space:]]*/ {
          item=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", item)
          if (item != "" && item != "none") found=1
        }
        END { exit found ? 0 : 1 }
      ' "$change_dir/proposal.md"; then
        touches_tables=1
      fi
    fi
    if [[ "$touches_tables" -eq 1 ]]; then
      echo "提示：本变更涉及数据库，建议运行 ai ship $change_id --review 做独立二审。"
    elif [[ -f "$change_dir/proposal.md" ]] && sed '/^## 待确认问题/,$d' "$change_dir/proposal.md" | grep -qE '支付|权限|状态流转' 2>/dev/null; then
      echo "提示：本变更涉及权限/支付/状态流，建议运行 ai ship $change_id --review 做独立二审。"
    fi
    echo "SHIP_GATES_PASSED: 门禁全部通过（二审未运行；需要时 ai ship $change_id --review）。"
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
