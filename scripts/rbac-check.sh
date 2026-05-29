#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGE_DIR="${1:-}"

if [[ -z "$CHANGE_DIR" || ! -d "$CHANGE_DIR" ]]; then
  echo "Usage: $0 openspec/changes/<change-id>" >&2
  exit 1
fi

fail=0
FILES=()
ACCESS_CONTROL_MODE="${ACCESS_CONTROL_MODE:-pending}"

source_env() {
  local file="$1"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

normalize_mode() {
  local value
  value="$(printf '%s' "${1:-pending}" | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    local|self|service|in-service|yes|y|true|1|是|需要|本服务|本服务建设|自建|建设)
      printf 'local'
      ;;
    external|gateway|iam|sso|no|n|false|0|否|外部|外部系统|网关|不建设)
      printf 'external'
      ;;
    none|public|open|skip|无|无需|不需要|不适用|公开)
      printf 'none'
      ;;
    *)
      printf 'pending'
      ;;
  esac
}

source_env "$SCRIPT_ROOT/.ai-control/project.env"
ACCESS_CONTROL_MODE="$(normalize_mode "${ACCESS_CONTROL_MODE:-pending}")"

while IFS= read -r file; do
  FILES+=("$file")
done < <(find "$CHANGE_DIR" -type f -name '*.md' | sort)

error() {
  printf '[FAIL] %s\n' "$*"
  fail=1
}

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "Access control check passed. no markdown files"
  exit 0
fi

matches_any() {
  local pattern="$1"
  grep -Eiq "$pattern" "${FILES[@]}" 2>/dev/null
}

has_heading_any() {
  local pattern="$1"
  grep -Eq "^##[[:space:]]+($pattern)" "${FILES[@]}" 2>/dev/null
}

has_affected_page() {
  local file
  for file in "$CHANGE_DIR/proposal.md" "$CHANGE_DIR/design.md"; do
    [[ -f "$file" ]] || continue
    awk '
      /^[[:space:]]*affected_pages:/ { in_pages=1; next }
      in_pages && /^[[:space:]]*[a-zA-Z_]+:/ { in_pages=0 }
      in_pages && /^[[:space:]]*-[[:space:]]*/ {
        item=$0
        sub(/^[[:space:]]*-[[:space:]]*/, "", item)
        if (item != "" && item != "none") found=1
      }
      END { exit found ? 0 : 1 }
    ' "$file" && return 0
  done
  return 1
}

is_background_change() {
  matches_any '(^|[[:space:]`])((GET|POST|PUT|DELETE|PATCH)[[:space:]]+)?/(api/)?(admin|platform)(/|[[:space:]`]|$)|后台|管理端|管理后台|运营后台|平台管理'
}

require_pattern() {
  local label="$1"
  local pattern="$2"
  if ! matches_any "$pattern"; then
    error "访问控制: $label is missing"
  fi
}

require_field_value() {
  local label="$1"
  local pattern="$2"

  awk -v pattern="$pattern" '
    $0 ~ pattern {
      line=$0
      sub(/^[[:space:]]*[-*]?[[:space:]]*/, "", line)
      sub(/^[^:：]*[:：]/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "" && line != "none" && line != "无") {
        found=1
      }
    }
    END { exit found ? 0 : 1 }
  ' "${FILES[@]}" 2>/dev/null || error "访问控制: $label must have a value or explicit 待确认 note"
}

detect_mode_from_docs() {
  if matches_any '访问控制模式[[:space:]]*[:：].*(本服务|自建|建设[[:space:]]*RBAC|local|service)|本服务是否建设[[:space:]]*RBAC[[:space:]]*[:：][[:space:]]*是'; then
    printf 'local'
  elif matches_any '访问控制模式[[:space:]]*[:：].*(不适用|无需|不需要|公开|none|public)|本服务是否建设[[:space:]]*RBAC[[:space:]]*[:：].*(不适用|无需|不需要)'; then
    printf 'none'
  elif matches_any '访问控制模式[[:space:]]*[:：].*(外部|网关|IAM|SSO|external|gateway)|本服务是否建设[[:space:]]*RBAC[[:space:]]*[:：][[:space:]]*否'; then
    printf 'external'
  else
    printf '%s' "$ACCESS_CONTROL_MODE"
  fi
}

if ! is_background_change; then
  echo "Access control check passed. no background/admin scope detected"
  exit 0
fi

if ! has_heading_any '访问控制|RBAC 权限|权限设计|鉴权说明|API 安全|安全设计'; then
  error "访问控制: missing section heading, add '## 访问控制' or '## 权限设计'"
fi

MODE="$(detect_mode_from_docs)"

require_field_value "无权限处理" '无权限处理|无权限返回|权限失败'
require_field_value "越权处理" '越权处理|越权'
require_pattern "无权限或越权处理" '无权限|越权|未授权|拒绝访问|权限失败|FORBIDDEN|403'
require_pattern "安全审查任务" 'agent-security|安全工程师|访问控制|RBAC|权限审查|越权'

case "$MODE" in
  local)
    require_pattern "本服务 RBAC 边界" 'RBAC|本服务|角色|平台管理|管理员|运营|供应商|专家|role'
    require_pattern "权限码或权限点" '权限码|权限点|菜单权限|按钮权限|permission|[a-z][a-z0-9_-]*:[a-z0-9:_-]+'
    require_field_value "允许角色" '允许主体|允许角色|角色'
    require_field_value "权限码或权限点" '权限码|权限点|鉴权方式'
    ;;
  external)
    require_pattern "外部访问控制责任系统" '外部|网关|IAM|SSO|统一认证|权限服务|责任系统|调用方|鉴权方式|header|token'
    require_field_value "责任系统或鉴权方式" '责任系统|鉴权方式|访问控制模式'
    ;;
  none)
    require_pattern "不适用原因和风险" '不适用|无需|不需要|公开|原因|风险|暴露面'
    ;;
  *)
    require_pattern "角色或访问边界" '访问控制|RBAC|角色|调用方|平台管理|管理员|运营|供应商|专家|role|权限'
    require_pattern "权限或鉴权说明" '权限码|权限点|鉴权方式|菜单权限|按钮权限|permission|外部|网关|IAM|SSO|不适用|待确认'
    ;;
esac

if has_affected_page; then
  require_pattern "后台页面权限态" '权限态|菜单权限|按钮权限|隐藏|禁用|无权限|403|拒绝访问|不展示|不可见'
fi

if [[ "$fail" -eq 1 ]]; then
  echo "Access control check failed. mode=$MODE"
  exit 2
fi

echo "Access control check passed. mode=$MODE"
