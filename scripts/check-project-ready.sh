#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
WARN=0

ok() {
  printf '[OK] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
  WARN=$((WARN + 1))
}

fail() {
  printf '[FAIL] %s\n' "$*"
  FAIL=$((FAIL + 1))
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

check_file() {
  local path="$1"
  if [[ -e "$ROOT/$path" ]]; then
    ok "$path"
  else
    fail "缺少 $path"
  fi
}

source_env() {
  local file="$1"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

if [[ ! -f "$ROOT/.ai-control/project.env" && -x "$ROOT/scripts/detect-project-profile.sh" ]]; then
  "$ROOT/scripts/detect-project-profile.sh" --write "$ROOT" >/dev/null
fi

source_env "$ROOT/.ai-control/project.env"
source_env "$ROOT/.agent/project.env"

printf '==> 控制系统文件\n'
check_file "AGENTS.md"
check_file "CONTEXT.md"
check_file "openspec/config.yaml"
check_file "agents/agent-product.md"
check_file "agents/agent-openspec.md"
check_file "agents/agent-release.md"
check_file "scripts/run-tests.sh"
check_file "scripts/openspec-language-check.sh"

printf '\n==> 项目画像\n'
if [[ -f "$ROOT/.ai-control/project.env" ]]; then
  ok ".ai-control/project.env"
  printf 'profile=%s backend=%s frontend=%s\n' "${AI_CONTROL_PROFILE:-待确认}" "${BACKEND_DIR:-待确认}" "${FRONTEND_DIR:-待确认}"
  printf 'access_control=%s\n' "${ACCESS_CONTROL_MODE:-pending}"
else
  warn "未生成 .ai-control/project.env"
fi

if [[ -f "$ROOT/.ai-control/project-profile.md" ]]; then
  ok ".ai-control/project-profile.md"
else
  warn "未生成 .ai-control/project-profile.md"
fi

printf '\n==> 基础工具\n'
has_command bash && ok "bash" || fail "bash 不可用"
has_command git && ok "git" || warn "git 不可用，建议安装后纳入版本管理"
has_command rg && ok "rg" || warn "rg 不可用，搜索会变慢"

printf '\n==> OpenSpec CLI（可选）\n'
if has_command openspec; then
  openspec_version="$(openspec --version 2>/dev/null || true)"
  ok "openspec ${openspec_version:-已安装}"
else
  warn "未安装官方 OpenSpec CLI；本控制系统仍可使用 scripts/ai-dev.sh 和本地 openspec/ 目录。"
  if has_command npm; then
    printf '      可选安装: npm install -g @fission-ai/openspec@latest\n'
  else
    warn "未检测到 npm；如需官方 OpenSpec CLI，请先安装 Node.js/npm。"
  fi
fi

if [[ "${HAS_SPRING_BOOT:-0}" == "1" ]]; then
  printf '\n==> Java / Spring Boot\n'
  has_command java && ok "java" || fail "检测到 Spring Boot，但 java 不可用"
  if [[ -n "${BACKEND_DIR:-}" && -x "$ROOT/$BACKEND_DIR/mvnw" ]]; then
    ok "$BACKEND_DIR/mvnw"
  elif [[ -x "$ROOT/mvnw" ]]; then
    ok "mvnw"
  elif has_command mvn; then
    ok "mvn"
  else
    warn "检测到 Spring Boot，但未找到 mvn/mvnw"
  fi
fi

if [[ "${HAS_NODE:-0}" == "1" ]]; then
  printf '\n==> Node / 前端\n'
  has_command node && ok "node" || fail "检测到 package.json，但 node 不可用"
  case "${PACKAGE_MANAGER:-npm}" in
    pnpm) has_command pnpm && ok "pnpm" || warn "推荐 pnpm，但 pnpm 不可用" ;;
    yarn) has_command yarn && ok "yarn" || warn "推荐 yarn，但 yarn 不可用" ;;
    *) has_command npm && ok "npm" || warn "推荐 npm，但 npm 不可用" ;;
  esac
fi

if [[ "${HAS_GO:-0}" == "1" ]]; then
  printf '\n==> Go\n'
  has_command go && ok "go" || fail "检测到 go.mod，但 go 不可用"
fi

if [[ "${HAS_PHP:-0}" == "1" ]]; then
  printf '\n==> PHP\n'
  has_command php && ok "php" || fail "检测到 composer.json，但 php 不可用"
  has_command composer && ok "composer" || warn "composer 不可用"
fi

printf '\n==> deepv4\n'
if [[ -f "$ROOT/.agent/deepv4.env" ]]; then
  source_env "$ROOT/.agent/deepv4.env"
  if [[ -n "${DEEPV4_BASE_URL:-}" && -n "${DEEPV4_API_KEY:-}" && -n "${DEEPV4_MODEL:-}" ]]; then
    ok ".agent/deepv4.env 已配置"
  else
    warn ".agent/deepv4.env 存在，但 DEEPV4_BASE_URL / DEEPV4_API_KEY / DEEPV4_MODEL 不完整"
  fi
else
  warn "未启用 deepv4；需要二审时复制 templates/deepv4.env.example 到 .agent/deepv4.env"
fi

printf '\n==> 检查脚本\n'
if [[ -x "$ROOT/scripts/agent-check.sh" ]]; then
  "$ROOT/scripts/agent-check.sh" >/dev/null && ok "agent-check" || warn "agent-check 有警告"
fi
if [[ -x "$ROOT/scripts/docs-link-check.sh" ]]; then
  "$ROOT/scripts/docs-link-check.sh" >/dev/null && ok "docs-link-check" || warn "docs-link-check 有警告"
fi
if [[ -x "$ROOT/scripts/openspec-language-check.sh" ]]; then
  "$ROOT/scripts/openspec-language-check.sh" "$ROOT/openspec" >/dev/null 2>&1 && ok "openspec-language-check" || warn "openspec-language-check 有警告"
fi

printf '\n==> 结果\n'
if [[ "$FAIL" -gt 0 ]]; then
  printf 'READY_FAILED: fail=%s warn=%s\n' "$FAIL" "$WARN"
  exit 2
fi

printf 'READY_OK: warn=%s\n' "$WARN"
