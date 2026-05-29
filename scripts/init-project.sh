#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$SCRIPT_ROOT"
PROJECT_NAME="$(basename "$ROOT")"
FORCE=0
NAME_PROVIDED=0

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/init-project.sh [--name <project-name>] [--force] [project-root]

Creates project-specific openspec/project.md and CONTEXT.md drafts from the current repository.
It scans common tech-stack files but does not invent business rules.
USAGE
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --name)
      [[ "${2:-}" ]] || { echo "--name requires a value" >&2; exit 2; }
      PROJECT_NAME="$2"
      NAME_PROVIDED=1
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "${TARGET_ROOT:-}" ]]; then
        TARGET_ROOT="$1"
        shift
      else
        echo "Only one project-root is allowed" >&2
        usage
        exit 2
      fi
      ;;
  esac
done

if [[ -n "${TARGET_ROOT:-}" ]]; then
  [[ -d "$TARGET_ROOT" ]] || { echo "Project root does not exist: $TARGET_ROOT" >&2; exit 2; }
  ROOT="$(cd "$TARGET_ROOT" && pwd)"
  if [[ "$NAME_PROVIDED" -eq 0 ]]; then
    PROJECT_NAME="$(basename "$ROOT")"
  fi
fi

detect_stack() {
  local items=()

  if find "$ROOT" -maxdepth 3 -name pom.xml -print -quit | grep -q .; then
    items+=("Java / Maven")
    if grep -R "<artifactId>spring-boot-starter-parent</artifactId>" "$ROOT" --include pom.xml >/dev/null 2>&1; then
      items+=("Spring Boot")
    fi
  fi

  if find "$ROOT" -maxdepth 3 -name package.json -print -quit | grep -q .; then
    items+=("Node.js")
    if grep -R '"vue"' "$ROOT" --include package.json >/dev/null 2>&1; then
      items+=("Vue")
    fi
    if grep -R '"react"' "$ROOT" --include package.json >/dev/null 2>&1; then
      items+=("React")
    fi
    if find "$ROOT" -maxdepth 3 -name pnpm-lock.yaml -print -quit | grep -q .; then
      items+=("pnpm")
    elif find "$ROOT" -maxdepth 3 -name package-lock.json -print -quit | grep -q .; then
      items+=("npm")
    fi
  fi

  if find "$ROOT" -maxdepth 3 \( -name 'docker-compose.yml' -o -name 'compose.yml' -o -name 'docker-compose.yaml' -o -name 'compose.yaml' \) -print -quit | grep -q .; then
    items+=("Docker Compose")
  fi

  if [[ "${#items[@]}" -eq 0 ]]; then
    printf '待确认'
  else
    printf '%s\n' "${items[@]}" | awk '!seen[$0]++' | awk 'NR == 1 { out=$0; next } { out=out ", " $0 } END { print out }'
  fi
}

guard_file() {
  local file="$1"
  if [[ -f "$file" && "$FORCE" -ne 1 ]]; then
    echo "[SKIP] ${file#$ROOT/} exists. Re-run with --force to overwrite."
    return 1
  fi
  return 0
}

TECH_STACK="$(detect_stack)"
mkdir -p "$ROOT/openspec"

if [[ -x "$SCRIPT_ROOT/scripts/detect-project-profile.sh" ]]; then
  "$SCRIPT_ROOT/scripts/detect-project-profile.sh" --write --name "$PROJECT_NAME" "$ROOT" >/dev/null
  echo "[WRITE] .ai-control/project.env"
  echo "[WRITE] .ai-control/project-profile.md"
fi

if guard_file "$ROOT/openspec/project.md"; then
  cat > "$ROOT/openspec/project.md" <<EOF
# $PROJECT_NAME

## 项目定位
待填写：说明项目定位、目标用户、业务价值和当前痛点。

## 目标用户
- 待确认：

## 核心能力
- 待确认：

## 技术栈
- 检测结果：$TECH_STACK

## 访问控制
- 模式：待确认。
- 本服务是否建设 RBAC：待确认。
- 说明：可以在 \`.ai-control/project.env\` 中把 \`ACCESS_CONTROL_MODE\` 设置为 \`local\`、\`external\` 或 \`none\`；后台功能实现前必须确认访问控制方案。

## 领域语言
待填写：高频业务术语、缩写、状态名和角色名。

## 范围
待填写：当前项目包含什么、不包含什么。

## 治理规则
- 非简单任务必须先创建或读取 \`openspec/changes/<change-id>/\`。
- 已确认业务规则必须沉淀到 \`openspec/specs/<capability>/spec.md\`。
- 设计决策和风险必须记录到对应 change 的 \`design.md\`。
- 实施任务必须记录到对应 change 的 \`tasks.md\`。
- 实现完成后必须归档已确认规格。
- Codex 实现前必须确认业务规则，不能自行决定字段、状态、权限或接口契约。
- 测试从根目录统一执行 \`bash scripts/run-tests.sh\`。

## 待确认问题
- 用户角色和权限边界是什么。
- 本服务是否建设 RBAC，或由外部系统、网关、IAM/SSO 负责访问控制。
- 是否存在租户、组织或数据隔离规则。
- API 统一响应格式、分页格式、错误码和鉴权方式是什么。
- 数据库表结构、字段含义、索引和迁移策略是什么。
EOF
  echo "[WRITE] openspec/project.md"
fi

if guard_file "$ROOT/CONTEXT.md"; then
  cat > "$ROOT/CONTEXT.md" <<EOF
# 项目上下文

本文件记录 \`$PROJECT_NAME\` 的业务语言和待确认概念。它不是某个具体需求的实现说明；具体功能必须进入 \`openspec/changes/<change-id>/\` 确认。

## 业务领域
待填写：项目所属业务领域和核心业务流程。

## 已确认角色
- 待确认：

## 业务术语

**待确认术语**:
说明术语含义。
_状态_: 待确认。

## 状态候选
以下状态仅作为建模候选，不能直接实现：

- 待确认：

## 已确认技术上下文
- Detected: $TECH_STACK
- 统一验证入口：\`bash scripts/run-tests.sh\`。

## 必须确认后才能实现的规则
- 角色和权限边界。
- 访问控制模式：本服务 RBAC、外部系统负责或明确不适用。
- 租户和数据隔离规则。
- 状态流转。
- 删除、撤回、作废和归档规则。
- API 统一响应格式、错误码、分页格式和鉴权方式。
- MySQL 表结构、字段含义、索引和迁移 SQL。

## 使用约定
- 新需求先进入 OpenSpec change。
- 待确认候选只能用于讨论和建模，不能直接进入代码。
- 如果 Codex 需要实现代码，必须先确认相关业务规则和 OpenSpec 任务边界。
EOF
  echo "[WRITE] CONTEXT.md"
fi
