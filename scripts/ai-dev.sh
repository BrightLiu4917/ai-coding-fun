#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

COMMAND="${1:-help}"
if [[ "$#" -gt 0 ]]; then
  shift
fi

FORCE=0

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/ai-dev.sh <command> [args]

Commands:
  init [--force]              初始化最小项目卡片，包含访问控制模式，不写代码
  feature <change-id> [--force] 创建 OpenSpec 功能变更骨架
  ready <change-id>           检查 OpenSpec 是否可以进入实现
  test                        运行项目测试
  review                      准备并运行 deepv4 二审
  next                        查看下一步建议
  help                        查看帮助

Examples:
  bash scripts/ai-dev.sh init
  bash scripts/ai-dev.sh feature login-jwt
  bash scripts/ai-dev.sh ready login-jwt
  bash scripts/ai-dev.sh test
  bash scripts/ai-dev.sh review
USAGE
}

info() {
  printf '%s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 2
}

prompt_input() {
  local __var="$1"
  local label="$2"
  local default_value="${3:-}"
  local value=""

  if [[ -n "$default_value" ]]; then
    printf '  › %s（默认：%s）: ' "$label" "$default_value"
  else
    printf '  › %s: ' "$label"
  fi

  if IFS= read -r value; then
    value="${value:-$default_value}"
  else
    value="$default_value"
  fi

  [[ -n "$value" ]] || value="待确认"
  printf -v "$__var" '%s' "$value"
}

prompt_access_control_mode() {
  local __var="$1"
  local choice=""
  local mode="pending"

  printf '  › 访问控制模式，请选择：\n'
  printf '    1) 本服务建设 RBAC：本服务负责角色、权限点、菜单、按钮、接口和数据范围\n'
  printf '    2) 外部系统负责：网关、IAM、SSO 或统一权限服务负责，本服务只校验传入上下文\n'
  printf '    3) 不适用：当前项目或功能不需要访问控制，必须写清原因和风险\n'
  printf '    4) 待确认：现在还没想清楚，后续 OpenSpec 必须补全\n'
  printf '  › 请选择 1-4（默认：4）: '

  if IFS= read -r choice; then
    choice="${choice:-4}"
  else
    choice="4"
  fi

  case "$choice" in
    1) mode="local" ;;
    2) mode="external" ;;
    3) mode="none" ;;
    4) mode="pending" ;;
    *)
      warn "访问控制模式选择无效，已标记为待确认: $choice"
      mode="pending"
      ;;
  esac

  printf -v "$__var" '%s' "$mode"
}

prompt_yes_no() {
  local __var="$1"
  local label="$2"
  local default_value="${3:-n}"
  local value=""
  local normalized=""

  if [[ "$default_value" == "y" ]]; then
    printf '  › %s (Y/n): ' "$label"
  else
    printf '  › %s (y/N): ' "$label"
  fi

  if IFS= read -r value; then
    value="${value:-$default_value}"
  else
    value="$default_value"
  fi

  normalized="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  case "$normalized" in
    y|yes|1|true|是)
      printf -v "$__var" '1'
      ;;
    *)
      printf -v "$__var" '0'
      ;;
  esac
}

prompt_secret() {
  local __var="$1"
  local label="$2"
  local value=""

  printf '  › %s: ' "$label"
  if [[ -t 0 ]]; then
    IFS= read -r -s value || value=""
    printf '\n'
  else
    IFS= read -r value || value=""
  fi

  printf -v "$__var" '%s' "$value"
}

parse_common_flags() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --force)
        FORCE=1
        shift
        ;;
      *)
        fail "未知参数: $1"
        ;;
    esac
  done
}

write_file() {
  local file="$1"
  local content="$2"

  if [[ -f "$file" && "$FORCE" -ne 1 ]]; then
    warn "已存在，跳过: ${file#$ROOT/}。需要覆盖时加 --force。"
    return 0
  fi

  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$content" > "$file"
  info "[WRITE] ${file#$ROOT/}"
}

load_project_env() {
  if [[ -f "$ROOT/.ai-control/project.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$ROOT/.ai-control/project.env"
    set +a
  fi
}

replace_or_append_env() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp

  mkdir -p "$(dirname "$file")"
  if [[ ! -f "$file" ]]; then
    printf '# 本文件记录项目画像和 AI 控制配置，不放密钥。\n' > "$file"
  fi

  tmp="$(mktemp)"
  awk -v key="$key" -v line="${key}=${value}" '
    BEGIN { done=0 }
    $0 ~ "^[#[:space:]]*" key "=" {
      if (done == 0) {
        print line
        done=1
      }
      next
    }
    { print }
    END {
      if (done == 0) {
        print line
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

shell_quote() {
  printf "%q" "$1"
}

write_deepv4_env() {
  local base_url="$1"
  local api_key="$2"
  local model="$3"
  local file="$ROOT/.agent/deepv4.env"

  mkdir -p "$ROOT/.agent"
  {
    printf '# deepv4 二审配置。本文件包含密钥，不要提交到 git。\n'
    printf 'DEEPV4_BASE_URL=%s\n' "$(shell_quote "$base_url")"
    printf 'DEEPV4_API_KEY=%s\n' "$(shell_quote "$api_key")"
    printf 'DEEPV4_MODEL=%s\n' "$(shell_quote "$model")"
    printf 'DEEPV4_TEMPERATURE=%s\n' "$(shell_quote "0.1")"
    printf 'DEEPV4_CONNECT_TIMEOUT_SECONDS=%s\n' "$(shell_quote "10")"
    printf 'DEEPV4_TIMEOUT_SECONDS=%s\n' "$(shell_quote "180")"
    printf 'DEEPV4_REVIEW_COMMAND=%s\n' "$(shell_quote "bash scripts/providers/deepv4-openai-compatible.sh")"
  } > "$file"
  chmod 600 "$file" 2>/dev/null || true
  info "[WRITE] .agent/deepv4.env"
}

configure_deepv4() {
  local enable_deepv4=0
  local base_url=""
  local api_key=""
  local model=""
  local file="$ROOT/.agent/deepv4.env"

  prompt_yes_no enable_deepv4 "是否现在启用 deepv4 二审配置" "n"
  if [[ "$enable_deepv4" -ne 1 ]]; then
    return 0
  fi

  if [[ -f "$file" && "$FORCE" -ne 1 ]]; then
    warn "已存在，跳过 .agent/deepv4.env。需要覆盖 deepv4 配置时加 --force。"
    return 0
  fi

  prompt_input base_url "DEEPV4_BASE_URL" "https://api.deepseek.com/v1"
  prompt_secret api_key "DEEPV4_API_KEY"
  prompt_input model "DEEPV4_MODEL" "deepv4"

  if [[ -z "$api_key" ]]; then
    warn "DEEPV4_API_KEY 为空，已跳过 deepv4 配置。"
    return 0
  fi

  write_deepv4_env "$base_url" "$api_key" "$model"
}

describe_access_control_mode() {
  case "${1:-pending}" in
    local)
      printf '本服务建设 RBAC：本服务负责角色、权限点、菜单权限、按钮权限、接口权限和数据范围'
      ;;
    external)
      printf '外部系统负责访问控制：本服务不建设 RBAC，但必须写清责任系统、凭证传递、失败处理和越权处理'
      ;;
    none)
      printf '不适用：当前项目或功能不建设 RBAC，必须写清原因、暴露面和风险'
      ;;
    *)
      printf '待确认：实现前必须确认本服务是否建设 RBAC，或由外部系统负责访问控制'
      ;;
  esac
}

rbac_in_service_text() {
  case "${1:-pending}" in
    local) printf '是' ;;
    external) printf '否，外部系统负责访问控制' ;;
    none) printf '否，当前场景不适用' ;;
    *) printf '待确认' ;;
  esac
}

detect_project() {
  if [[ -x "$ROOT/scripts/detect-project-profile.sh" ]]; then
    if [[ ! -f "$ROOT/.ai-control/project.env" || "$FORCE" -eq 1 ]]; then
      "$ROOT/scripts/detect-project-profile.sh" --write "$ROOT" >/dev/null
    fi
  fi
  load_project_env
}

normalize_change_dir() {
  local change_id="$1"
  if [[ "$change_id" == openspec/changes/* ]]; then
    printf '%s\n' "$ROOT/$change_id"
  else
    printf '%s\n' "$ROOT/openspec/changes/$change_id"
  fi
}

validate_change_id() {
  local change_id="$1"
  [[ "$change_id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "change-id 必须使用小写中横线，例如 login-jwt"
}

contains_unresolved() {
  local change_dir="$1"
  local output_file="$2"
  grep -RInE '(^|[[:space:]-])(待确认[:：]|待确认$)|尚未确认|不能直接实现|真实实现前必须确认' "$change_dir" --include '*.md' >"$output_file" 2>/dev/null
}

cmd_init() {
  parse_common_flags "$@"

  info "==> 初始化最小项目卡片"
  local env_existed=0
  [[ -f "$ROOT/.ai-control/project.env" ]] && env_existed=1
  detect_project

  local project_name="${PROJECT_NAME:-$(basename "$ROOT")}"
  local backend_dir="${BACKEND_DIR:-待确认}"
  local frontend_dir="${FRONTEND_DIR:-待确认}"
  local profile="${AI_CONTROL_PROFILE:-待确认}"
  local tech_stack="检测结果：${profile}；后端目录：${backend_dir}；前端目录：${frontend_dir}"

  local project_desc project_type roles first_feature api_rule access_control_mode access_control_text
  prompt_input project_desc "项目一句话说明"
  prompt_input project_type "项目类型，例如后台管理/SaaS/小程序/业务系统"
  prompt_input roles "用户角色，用逗号分隔，例如平台管理,供应商,专家"
  prompt_input first_feature "第一个准备开发的功能"
  prompt_input api_rule "API 路径规则" "/api/admin/v1、/api/app/v1、/openapi/app/v1、/innerapi/app/v1；只用 GET/POST；不用路径参数"
  prompt_access_control_mode access_control_mode
  access_control_text="$(describe_access_control_mode "$access_control_mode")"

  if [[ "$env_existed" -eq 0 || "$FORCE" -eq 1 ]]; then
    replace_or_append_env "$ROOT/.ai-control/project.env" "ACCESS_CONTROL_MODE" "'$access_control_mode'"
  else
    warn "已存在，跳过 .ai-control/project.env。需要更新访问控制模式时加 --force。"
  fi

  write_file "$ROOT/openspec/project.md" "# ${project_name}

## 项目定位
${project_desc}

## 项目类型
${project_type}

## 技术栈
${tech_stack}

## 用户角色
${roles}

## API 规则
${api_rule}

## 访问控制
- 模式：${access_control_text}
- 本服务是否建设 RBAC：$(rbac_in_service_text "$access_control_mode")
- 约束：后台功能必须确认访问控制方案；如果由外部系统负责，必须写清责任系统、调用凭证、失败处理和越权处理。

## 当前范围
- 第一个功能：${first_feature}
- 其他功能：待确认

## 治理规则
- 新功能必须先进入 \`openspec/changes/<change-id>/\`。
- 字段、状态、权限、表结构、API 和响应格式不清楚时，必须先确认。
- 实现前必须运行 \`bash scripts/ai-dev.sh ready <change-id>\`。
- 测试统一运行 \`bash scripts/ai-dev.sh test\`。

## 待确认问题
- 详细业务流程待确认。
- 访问控制方式、责任系统、角色或调用方、权限点、无权限处理、越权处理和数据范围待确认。
- 数据库审计字段、租户规则、软删除规则待确认。"

  write_file "$ROOT/CONTEXT.md" "# 项目上下文

本文件只记录领域语言、业务术语和不能猜测的规则。项目定位、技术栈、角色、API 规则和访问控制模式以 \`openspec/project.md\` 为准。

## 领域术语
- 待确认：

## 状态候选
- 待确认：

## 业务规则待确认
- 待确认：

## 不能猜测的内容
- 字段含义。
- 状态流转。
- 访问控制方式、责任系统、角色、权限点、无权限处理和越权处理。
- 租户和数据范围。
- 删除、撤回、作废和归档规则。
- API 响应格式和错误码。

## 使用约定
- 第一版上下文只要求够 AI 不乱猜。
- 每个真实功能通过 OpenSpec 单独确认。
- 未确认内容只能写成待确认，不能直接实现。"

  configure_deepv4

  info ""
  info "下一步："
  info "  bash scripts/ai-dev.sh feature <change-id>"
  info "  例如：bash scripts/ai-dev.sh feature login-jwt"
}

cmd_feature() {
  local change_id=""
  FORCE=0
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --force)
        FORCE=1
        shift
        ;;
      -*)
        fail "未知参数: $1"
        ;;
      *)
        if [[ -n "$change_id" ]]; then
          fail "只能指定一个 change-id"
        fi
        change_id="$1"
        shift
        ;;
    esac
  done

  [[ -n "$change_id" ]] || fail "缺少 change-id，例如：bash scripts/ai-dev.sh feature login-jwt"
  validate_change_id "$change_id"
  load_project_env

  local change_dir="$ROOT/openspec/changes/$change_id"
  local capability="$change_id"
  local access_control_mode="${ACCESS_CONTROL_MODE:-pending}"
  local access_control_text
  access_control_text="$(describe_access_control_mode "$access_control_mode")"

  mkdir -p "$change_dir/specs/$capability"

  write_file "$change_dir/proposal.md" "# 变更提案：${change_id}

## 项目背景
待确认：说明为什么要做这个功能。

## 项目目标
待确认：说明用户目标和业务价值。

## 功能范围
- 待确认：本次要做什么。

## 影响范围
\`\`\`yaml
affected_files:
  - none
affected_tables:
  - none
affected_apis:
  - none
affected_pages:
  - none
affected_agents:
  - agent-product
  - agent-openspec
\`\`\`

## 非目标
- 待确认：本次明确不做什么。

## 风险说明
- 待确认：字段、状态、权限、表结构、API 和响应格式确认前不能实现。

## 待确认问题
- 待确认：访问控制方式、本服务是否建设 RBAC、用户角色或调用方和权限边界。
- 待确认：数据表和字段。
- 待确认：API 请求和响应。
- 待确认：测试和验收标准。"

  write_file "$change_dir/design.md" "# 设计说明：${change_id}

## 需求理解
待确认。

## 系统架构
待确认。

## 影响范围
\`\`\`yaml
affected_files:
  - none
affected_tables:
  - none
affected_apis:
  - none
affected_pages:
  - none
affected_agents:
  - agent-architect
  - agent-api
  - agent-dba
  - agent-test
\`\`\`

## 数据库设计
待确认。

## 接口设计
待确认。API 路径必须遵循 \`docs/API_RULES.md\`。

## 权限设计
- 访问控制模式：${access_control_text}
- 本服务是否建设 RBAC：$(rbac_in_service_text "$access_control_mode")
- 责任系统：待确认。
- 允许主体或角色：待确认。
- 权限码或权限点：待确认；如果由外部系统负责，可写外部权限标识或“不由本服务维护”。
- 菜单权限：待确认；如不适用必须写明原因。
- 按钮权限：待确认；如不适用必须写明原因。
- 无权限处理：待确认。
- 越权处理：待确认。
- 数据范围：待确认。
- 后台功能必须确认访问控制方案；如果由外部系统负责，必须写清责任系统、传递凭证、失败处理和越权处理。

## 验证方案
待确认。"

  write_file "$change_dir/tasks.md" "# 任务清单

## 需求确认
- [ ] 优先级：高；状态：待处理；负责人：用户/Codex；预计工时：30 分钟；验收标准：字段、状态、权限、API 和响应格式已确认。

## 设计确认
- [ ] 优先级：高；状态：待处理；负责人：Codex；预计工时：30 分钟；验收标准：数据库、接口、权限和测试方案已确认。

## 实现
- [ ] 优先级：中；状态：待处理；负责人：Codex；预计工时：待确认；验收标准：按已确认 OpenSpec 最小切片实现。

## 验证
- [ ] 优先级：高；状态：待处理；负责人：Codex；预计工时：30 分钟；验收标准：运行 \`bash scripts/ai-dev.sh test\` 并记录结果。

## 审查
- [ ] 优先级：中；状态：待处理；负责人：Codex/deepv4；预计工时：30 分钟；验收标准：完成发布审查或 deepv4 二审。"

  write_file "$change_dir/specs/$capability/spec.md" "# ${change_id} 规格

## 功能模块
待确认。

## 业务流程
待确认。

## 状态流转
待确认。

## 数据结构
待确认。

## 接口设计
待确认。

## 权限设计
待确认。

## 异常处理
待确认。

## 数据校验规则
待确认。

## 日志说明
待确认。"

  info ""
  info "复制给 Codex："
  cat <<EOF
请读取 openspec/changes/${change_id}。
先补全需求理解、功能范围、表结构影响、API、访问控制/RBAC、测试计划和待确认问题。
不要直接写代码。
EOF
}

cmd_ready() {
  local change_id="${1:-}"
  [[ -n "$change_id" ]] || fail "缺少 change-id，例如：bash scripts/ai-dev.sh ready login-jwt"
  local change_dir
  local unresolved_file
  change_dir="$(normalize_change_dir "$change_id")"
  [[ -d "$change_dir" ]] || fail "OpenSpec change 不存在: ${change_dir#$ROOT/}"
  unresolved_file="$(mktemp)"

  info "==> OpenSpec 检查"
  "$ROOT/scripts/openspec-check.sh" "$change_dir"

  if contains_unresolved "$change_dir" "$unresolved_file"; then
    warn "仍有待确认内容，暂时不要写代码："
    sed -n '1,40p' "$unresolved_file"
    rm -f "$unresolved_file"
    exit 2
  fi

  rm -f "$unresolved_file"
  info "READY_OK"
  info ""
  info "复制给 Codex："
  cat <<EOF
我已确认 openspec/changes/$(basename "$change_dir")。
请按 tasks.md 最小可验证切片实现。
实现后运行 bash scripts/ai-dev.sh test。
EOF
}

cmd_test() {
  "$ROOT/scripts/run-tests.sh"
}

cmd_review() {
  "$ROOT/scripts/prepare-deepv4-review.sh"
  "$ROOT/scripts/run-deepv4-review.sh"
}

cmd_next() {
  if [[ ! -f "$ROOT/.ai-control/project.env" || ! -f "$ROOT/CONTEXT.md" || ! -f "$ROOT/openspec/project.md" ]]; then
    info "下一步：bash scripts/ai-dev.sh init"
    exit 0
  fi

  local latest_change=""
  latest_change="$(ls -td "$ROOT"/openspec/changes/*/ 2>/dev/null | head -1 || true)"
  if [[ -z "$latest_change" ]]; then
    info "下一步：bash scripts/ai-dev.sh feature <change-id>"
    exit 0
  fi

  local unresolved_file
  unresolved_file="$(mktemp)"
  if contains_unresolved "$latest_change" "$unresolved_file"; then
    rm -f "$unresolved_file"
    info "下一步：把下面这段发给 Codex"
    cat <<EOF
请读取 openspec/changes/$(basename "$latest_change")。
帮我处理待确认问题，不要写代码。
EOF
    exit 0
  fi

  rm -f "$unresolved_file"
  info "下一步：bash scripts/ai-dev.sh ready $(basename "$latest_change")"
}

case "$COMMAND" in
  init)
    cmd_init "$@"
    ;;
  feature)
    cmd_feature "$@"
    ;;
  ready)
    cmd_ready "$@"
    ;;
  test)
    cmd_test "$@"
    ;;
  review)
    cmd_review "$@"
    ;;
  next)
    cmd_next "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    fail "未知命令: $COMMAND"
    ;;
esac
