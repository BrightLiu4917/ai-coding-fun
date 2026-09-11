#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
fi
AI_DEV_COMMAND="bash .ai-control/control/scripts/ai-dev.sh"

COMMAND="${1:-help}"
if [[ "$#" -gt 0 ]]; then
  shift
fi

FORCE=0

usage() {
  cat <<'USAGE'
Usage:
  bash .ai-control/control/scripts/ai-dev.sh <command> [args]

Commands:
  init [--force]              初始化最小项目卡片，包含访问控制模式，不写代码
  feature <change-id> [--force] 创建 OpenSpec 功能变更骨架（五件套完整流程）
  feature <change-id> --lite    小需求快速通道：只生成 proposal/tasks/test-cases，不允许涉及数据库和 API
  feature <change-id> --upgrade lite 升级为完整流程：保留已写内容，补 spec 骨架，需重新确认
  ready <change-id>           检查 OpenSpec 是否可以进入实现
  test                        运行项目测试
  review                      准备并运行独立二审
  next                        查看下一步建议
  help                        查看帮助

Examples:
  bash .ai-control/control/scripts/ai-dev.sh init
  bash .ai-control/control/scripts/ai-dev.sh feature login-jwt
  bash .ai-control/control/scripts/ai-dev.sh ready login-jwt
  bash .ai-control/control/scripts/ai-dev.sh test
  bash .ai-control/control/scripts/ai-dev.sh review
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
    warn "已存在，跳过: ${file#$PROJECT_ROOT/}。需要覆盖时加 --force。"
    return 0
  fi

  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$content" > "$file"
  info "[WRITE] ${file#$PROJECT_ROOT/}"
}

load_project_env() {
  if [[ -f "$PROJECT_ROOT/.ai-control/project.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/.ai-control/project.env"
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

write_review_env() {
  local base_url="$1"
  local api_key="$2"
  local model="$3"
  local file="$PROJECT_ROOT/.agent/review.env"

  mkdir -p "$PROJECT_ROOT/.agent"
  {
    printf '# 独立二审配置。本文件包含密钥，不要提交到 git。\n'
    printf 'REVIEW_BASE_URL=%s\n' "$(shell_quote "$base_url")"
    printf 'REVIEW_API_KEY=%s\n' "$(shell_quote "$api_key")"
    printf 'REVIEW_MODEL=%s\n' "$(shell_quote "$model")"
    printf 'REVIEW_TEMPERATURE=%s\n' "$(shell_quote "0.1")"
    printf 'REVIEW_CONNECT_TIMEOUT_SECONDS=%s\n' "$(shell_quote "10")"
    printf 'REVIEW_TIMEOUT_SECONDS=%s\n' "$(shell_quote "180")"
    printf '# provider: openai-compatible（DeepSeek/Kimi/通义/GLM/GPT/Ollama 等）或 anthropic（Claude 官方 API）\n'
    printf 'REVIEW_PROVIDER=%s\n' "$(shell_quote "openai-compatible")"
    printf '# 触发策略（ship 默认不跑二审，--review 主动触发）: always=每次 ship 必审 | auto/never=仅 --review 时跑\n'
    printf 'REVIEW_MODE=%s\n' "$(shell_quote "auto")"
  } > "$file"
  chmod 600 "$file" 2>/dev/null || true
  info "[WRITE] .agent/review.env"
}

configure_review() {
  local enable_review=0
  local base_url=""
  local api_key=""
  local model=""
  local file="$PROJECT_ROOT/.agent/review.env"

  prompt_yes_no enable_review "是否现在启用独立二审配置" "n"
  if [[ "$enable_review" -ne 1 ]]; then
    return 0
  fi

  if [[ -f "$file" && "$FORCE" -ne 1 ]]; then
    warn "已存在，跳过 .agent/review.env。需要覆盖二审配置时加 --force。"
    return 0
  fi

  prompt_input base_url "REVIEW_BASE_URL" "https://api.deepseek.com/v1"
  prompt_secret api_key "REVIEW_API_KEY"
  prompt_input model "REVIEW_MODEL" "deepseek-reasoner"

  if [[ -z "$api_key" ]]; then
    warn "REVIEW_API_KEY 为空，已跳过二审配置。"
    return 0
  fi

  write_review_env "$base_url" "$api_key" "$model"
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
    if [[ ! -f "$PROJECT_ROOT/.ai-control/project.env" || "$FORCE" -eq 1 ]]; then
      "$ROOT/scripts/detect-project-profile.sh" --write "$PROJECT_ROOT" >/dev/null
    fi
  fi
  load_project_env
}

normalize_change_dir() {
  local change_id="$1"
  if [[ "$change_id" == openspec/changes/* ]]; then
    printf '%s\n' "$PROJECT_ROOT/$change_id"
  else
    printf '%s\n' "$PROJECT_ROOT/openspec/changes/$change_id"
  fi
}

validate_change_id() {
  local change_id="$1"
  [[ "$change_id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "change-id 必须使用小写中横线，例如 login-jwt"
}

contains_unresolved() {
  # 只检查各文档"## 待确认问题"章节内是否还有未答条目（含"- 待确认"或问题小节且无"已确认"标记）。
  # 不再全文扫描"待确认"字样——避免逼 AI 为过门禁而编造内容（那违反"禁止发明"红线）。
  local change_dir="$1"
  local output_file="$2"
  : > "$output_file"
  local file
  while IFS= read -r file; do
    awk -v fname="${file#$PROJECT_ROOT/}" '
      /^## 待确认问题/ { in_sec=1; next }
      in_sec && /^## /  { in_sec=0 }
      in_sec && /^[[:space:]]*(-|###)[[:space:]]*/ {
        line=$0
        # 已答的条目应标注"已确认"或"已解决"，其余视为未答
        if (line !~ /已确认|已解决|无待确认|暂无/) {
          printf "%s: %s\n", fname, line
        }
      }
    ' "$file" >> "$output_file"
  done < <(find "$change_dir" -type f -name '*.md' 2>/dev/null | sort)
  [[ -s "$output_file" ]]
}

cmd_init() {
  parse_common_flags "$@"

  info "==> 初始化最小项目卡片"
  local env_existed=0
  [[ -f "$PROJECT_ROOT/.ai-control/project.env" ]] && env_existed=1
  detect_project

  local project_name="${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"
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
    replace_or_append_env "$PROJECT_ROOT/.ai-control/project.env" "ACCESS_CONTROL_MODE" "'$access_control_mode'"
  else
    warn "已存在，跳过 .ai-control/project.env。需要更新访问控制模式时加 --force。"
  fi

  write_file "$PROJECT_ROOT/openspec/project.md" "# ${project_name}

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
- 实现前必须运行 \`${AI_DEV_COMMAND} ready <change-id>\`。
- 测试统一运行 \`${AI_DEV_COMMAND} test\`。

## 待确认问题
- 详细业务流程待确认。
- 访问控制方式、责任系统、角色或调用方、权限点、无权限处理、越权处理和数据范围待确认。
- 数据库审计字段、租户规则、软删除规则待确认。"

  write_file "$PROJECT_ROOT/CONTEXT.md" "# 项目上下文

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

  configure_review

  info ""
  info "下一步："
  info "  ${AI_DEV_COMMAND} feature <change-id>"
  info "  例如：${AI_DEV_COMMAND} feature login-jwt"
}

cmd_feature() {
  local change_id=""
  FORCE=0
  LITE=0
  UPGRADE=0
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --force)
        FORCE=1
        shift
        ;;
      --lite)
        LITE=1
        shift
        ;;
      --upgrade)
        UPGRADE=1
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

  [[ -n "$change_id" ]] || fail "缺少 change-id，例如：${AI_DEV_COMMAND} feature login-jwt"
  validate_change_id "$change_id"
  load_project_env

  local change_dir="$PROJECT_ROOT/openspec/changes/$change_id"
  local capability="$change_id"
  local access_control_mode="${ACCESS_CONTROL_MODE:-pending}"
  local access_control_text
  access_control_text="$(describe_access_control_mode "$access_control_mode")"

  # lite 升级为完整流程：保留已写内容，去掉 lite 标记，只补缺失的 spec 骨架。
  # 替代"推倒重来"——升级后影响范围已变，必须重新经用户确认。
  if [[ "$UPGRADE" -eq 1 ]]; then
    [[ -d "$change_dir" ]] || fail "change 不存在，无法升级: $change_id"
    if grep -q '^变更级别: lite' "$change_dir/proposal.md" 2>/dev/null; then
      local tmp_upgrade
      tmp_upgrade="$(mktemp)"
      grep -v '^变更级别: lite' "$change_dir/proposal.md" > "$tmp_upgrade"
      mv "$tmp_upgrade" "$change_dir/proposal.md"
      info "已移除 lite 标记。"
    fi
    mkdir -p "$change_dir/specs/$capability"
    FORCE=0
    write_file "$change_dir/specs/$capability/spec.md" "# ${change_id} 规格

## 场景
（补全：用户在什么情况下做什么、系统给出什么可观察结果）

#### 场景：（场景名）
- （给定…时…则…）

## 值域
（补全：涉及的字段、枚举、状态和约束；来源必须是已确认事实）

## 待确认问题
- （没有则写：无待确认）"
    info ""
    info "已升级为完整流程：既有 proposal/tasks/test-cases 全部保留。"
    info "注意：升级意味着影响范围变化，必须重新经用户确认；涉及数据库时先走数据库工程师两阶段确认。"
    return 0
  fi

  # 小需求快速通道：只生成 proposal + tasks + test-cases 三个轻量文件。
  # 门禁保证 lite 不被滥用：影响范围声明了数据库或接口时，impact-check 会要求升级为完整流程。
  if [[ "$LITE" -eq 1 ]]; then
    mkdir -p "$change_dir"

    write_file "$change_dir/proposal.md" "# 变更提案：${change_id}

变更级别: lite

## 需求说明
待确认：一两句话说清楚要改什么、为什么。

## 影响范围

affected_files:
  - 待确认
affected_tables:
  - none
affected_apis:
  - none
affected_pages:
  - none
affected_agents:
  - none

## 待确认问题
- 待确认。"

    write_file "$change_dir/tasks.md" "# 任务清单

## 实现
- [ ] 优先级：中；状态：待处理；负责人：AI 助手；预计工时：待确认；验收标准：按已确认 proposal 最小实现。

## 验证
- [ ] 优先级：高；状态：待处理；负责人：AI 助手；预计工时：15 分钟；验收标准：按 test-cases.md 执行并回填状态，运行 \`${AI_DEV_COMMAND} test\`。"

    write_file "$change_dir/test-cases.md" "# 测试用例

> lite 变更同样需要验收用例；验收以 JUnit 报告或交付说明中的手动验证结果为证据。

## 用例清单

| 用例ID | 关联场景 | 类型 | 前置条件 | 步骤 | 预期结果 | 验证方式 |
|--------|----------|------|----------|------|----------|----------|
| TC-01 | （补全） | 正常流 | （补全） | （补全） | （补全） | 手动 |

- 类型：正常流 / 异常流 / 权限 / 边界 / 兼容性 / 并发
- 验证方式：单测 / 集成 / E2E / 手动（手动用例的执行结果写入交付说明）"

    info ""
    info "lite 变更骨架已生成（proposal / tasks / test-cases）。"
    info "注意：lite 不允许涉及数据库表或 API 契约；如需涉及，运行 feature <change-id> --upgrade 升级（保留已写内容）。"
    info ""
    info "复制给 AI 助手："
    cat <<EOF
请读取 openspec/changes/${change_id}（lite 变更）。
补全需求说明、影响文件和测试用例，列出待确认问题。
本变更不涉及数据库和 API 契约；如发现需要涉及，停止并运行 ${AI_DEV_COMMAND} feature ${change_id} --upgrade 升级（保留已写内容），升级后重新请求确认。
不要直接写代码。
EOF
    return 0
  fi

  mkdir -p "$change_dir/specs/$capability"

  write_file "$change_dir/proposal.md" "# 变更提案：${change_id}

## 项目背景
（补全：为什么要做这个功能）

## 项目目标
（补全：用户目标和业务价值）

## 功能范围
- （补全：本次要做什么）

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
  - agent-spec
\`\`\`

## 非目标
- （补全：本次明确不做什么）

## 待确认问题
- 访问控制：本功能沿用项目级模式（${access_control_text}）还是另有要求？
- 数据表：涉及哪些表/字段/索引？（涉及则必须走数据库工程师两阶段确认）
- API 契约：路径、请求、响应、分页、错误码？（遵循 rules/20-api.md）
- 验收标准：最小可验证路径、失败路径、越权场景分别是什么？"

  # design.md 不再默认生成：涉及跨模块、数据库、接口兼容或状态流转时，
  # 由 AI 按模板（templates/openspec-change/design.md）按需创建。

  write_file "$change_dir/tasks.md" "# 任务清单

- [ ] 需求确认：字段、状态、权限、API 和响应格式已确认。
- [ ] 实现：按已确认 OpenSpec 最小切片实现。
- [ ] 验证：运行 \`${AI_DEV_COMMAND} test\`，JUnit 报告全绿。
- [ ] 交付：过 \`ai ship\` 门禁；高风险变更建议 \`ai ship --review\`。"

  write_file "$change_dir/test-cases.md" "# 测试用例

> 设计期由测试工程师产出，随 change 一起确认；验收以 JUnit 报告为证据（测试名带用例ID），不维护状态列。

## 用例清单

| 用例ID | 关联场景 | 类型 | 前置条件 | 步骤 | 预期结果 | 验证方式 |
|--------|----------|------|----------|------|----------|----------|
| TC-01 | （补全） | 正常流 | （补全） | （补全） | （补全） | 单测 |

- 类型：正常流 / 异常流 / 权限 / 边界 / 兼容性 / 并发
- 验证方式：单测 / 集成 / E2E / 手动（手动用例的执行结果写入交付说明）

## 测试命令

\`\`\`bash
${AI_DEV_COMMAND} test
\`\`\`

## 手动验证步骤
- 待确认。

## 残余风险
- 待确认。"

  write_file "$change_dir/specs/$capability/spec.md" "# ${change_id} 规格

## 场景
（补全：用户在什么情况下做什么、系统给出什么可观察结果；每个场景一小节。
涉及状态流转、权限或异常处理时在对应场景内写清，不单独开章节。）

#### 场景：（场景名）
- （给定…时…则…）

## 值域
（补全：本功能涉及的字段、枚举值、状态和约束；来源必须是已确认事实，禁止发明。）

## 待确认问题
- （没有则写：无待确认）"

  info ""
  info "复制给 AI 助手："

  # 根据影响范围动态生成本次需要读的规则清单
  RULES_HINT="基础必读：.ai-control/control/rules/01-code-change.md + 对应栈规则。"
  if grep -qE '^\s*-[^\n]*[a-zA-Z]' <(sed -n '/^## 影响范围/,/^## /p' "$change_dir/proposal.md" 2>/dev/null | sed -n '/^affected_tables/,/^[^ ]/p' | head -10) 2>/dev/null && \
     ! grep -qE '^\s*-\s*none\s*$' <(sed -n '/^## 影响范围/,/^## /p' "$change_dir/proposal.md" 2>/dev/null | sed -n '/^affected_tables/,/^[^ ]/p' | head -10) 2>/dev/null; then
    RULES_HINT="$RULES_HINT 必须读取：.ai-control/control/rules/10-db-schema.md。"
  fi
  if grep -qE '^\s*-[^\n]*[a-zA-Z]' <(sed -n '/^## 影响范围/,/^## /p' "$change_dir/proposal.md" 2>/dev/null | sed -n '/^affected_apis/,/^[^ ]/p' | head -10) 2>/dev/null && \
     ! grep -qE '^\s*-\s*none\s*$' <(sed -n '/^## 影响范围/,/^## /p' "$change_dir/proposal.md" 2>/dev/null | sed -n '/^affected_apis/,/^[^ ]/p' | head -10) 2>/dev/null; then
    RULES_HINT="$RULES_HINT 必须读取：.ai-control/control/rules/20-api.md。"
  fi
  if grep -qE '^\s*-[^\n]*[a-zA-Z]' <(sed -n '/^## 影响范围/,/^## /p' "$change_dir/proposal.md" 2>/dev/null | sed -n '/^affected_pages/,/^[^ ]/p' | head -10) 2>/dev/null && \
     ! grep -qE '^\s*-\s*none\s*$' <(sed -n '/^## 影响范围/,/^## /p' "$change_dir/proposal.md" 2>/dev/null | sed -n '/^affected_pages/,/^[^ ]/p' | head -10) 2>/dev/null; then
    RULES_HINT="$RULES_HINT 前端相关：.ai-control/control/rules/30-frontend.md + 对应栈规则（31-vue3 / 32-react）。"
  fi

  cat <<EOF
请读取 openspec/changes/${change_id}。
本次规则要求：${RULES_HINT}
按规则约束补全需求理解、功能范围和待确认问题。不需要读本次未涉及的规则。
不要直接写代码。
EOF
}

cmd_ready() {
  local change_id="${1:-}"
  [[ -n "$change_id" ]] || fail "缺少 change-id，例如：${AI_DEV_COMMAND} ready login-jwt"
  local change_dir
  local unresolved_file
  change_dir="$(normalize_change_dir "$change_id")"
  [[ -d "$change_dir" ]] || fail "OpenSpec change 不存在: ${change_dir#$PROJECT_ROOT/}"
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
  info "复制给 AI 助手："
  cat <<EOF
我已确认 openspec/changes/$(basename "$change_dir")。
请按 tasks.md 最小可验证切片实现。
实现后运行 ${AI_DEV_COMMAND} test。
EOF
}

cmd_test() {
  "$ROOT/scripts/run-tests.sh"
}

cmd_review() {
  "$ROOT/scripts/prepare-review.sh"
  "$ROOT/scripts/run-review.sh"
}

cmd_next() {
  if [[ ! -f "$PROJECT_ROOT/.ai-control/project.env" || ! -f "$PROJECT_ROOT/CONTEXT.md" || ! -f "$PROJECT_ROOT/openspec/project.md" ]]; then
    info "下一步：${AI_DEV_COMMAND} init"
    exit 0
  fi

  local latest_change=""
  latest_change="$(ls -td "$PROJECT_ROOT"/openspec/changes/*/ 2>/dev/null | head -1 || true)"
  if [[ -z "$latest_change" ]]; then
    info "下一步：${AI_DEV_COMMAND} feature <change-id>"
    exit 0
  fi

  local unresolved_file
  unresolved_file="$(mktemp)"
  if contains_unresolved "$latest_change" "$unresolved_file"; then
    rm -f "$unresolved_file"
    info "下一步：把下面这段发给 AI 助手"
    cat <<EOF
请读取 openspec/changes/$(basename "$latest_change")。
帮我处理待确认问题，不要写代码。
EOF
    exit 0
  fi

  rm -f "$unresolved_file"
  info "下一步：${AI_DEV_COMMAND} ready $(basename "$latest_change")"
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
