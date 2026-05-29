#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="$ROOT"
PROJECT_NAME=""
WRITE=0

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/detect-project-profile.sh [--write] [--name <project-name>] [project-root]

Detects the target project's tech stack and recommends an AI control profile.

Options:
  --write              Write .ai-control/project.env and .ai-control/project-profile.md.
  --name <name>        Project display name. Defaults to project directory name.
  -h, --help           Show help.
USAGE
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 2
}

contains_file() {
  local pattern="$1"
  find "$TARGET_ROOT" -maxdepth 4 -name "$pattern" -print -quit 2>/dev/null | grep -q .
}

grep_project() {
  local pattern="$1"
  find "$TARGET_ROOT" \
    -path "$TARGET_ROOT/.git" -prune -o \
    -path "*/node_modules" -prune -o \
    -path "*/vendor" -prune -o \
    -path "*/target" -prune -o \
    -path "*/dist" -prune -o \
    -maxdepth 4 \
    -type f \
    -exec grep -E "$pattern" {} + >/dev/null 2>&1
}

first_dir_with_file() {
  local file_name="$1"
  local preferred
  for preferred in api server backend service app vue web frontend admin client; do
    if [[ -f "$TARGET_ROOT/$preferred/$file_name" ]]; then
      printf '%s\n' "$preferred"
      return 0
    fi
  done

  local found
  found="$(find "$TARGET_ROOT" -maxdepth 3 -name "$file_name" -print -quit 2>/dev/null || true)"
  if [[ -n "$found" ]]; then
    dirname "${found#$TARGET_ROOT/}"
  fi
}

detect_node_package_manager() {
  local dir="$1"
  [[ -n "$dir" ]] || dir="."
  if [[ -f "$TARGET_ROOT/$dir/pnpm-lock.yaml" ]]; then
    printf 'pnpm'
  elif [[ -f "$TARGET_ROOT/$dir/yarn.lock" ]]; then
    printf 'yarn'
  elif [[ -f "$TARGET_ROOT/$dir/package-lock.json" ]]; then
    printf 'npm'
  elif contains_file pnpm-lock.yaml; then
    printf 'pnpm'
  elif contains_file yarn.lock; then
    printf 'yarn'
  else
    printf 'npm'
  fi
}

detect_test_command() {
  local backend_dir="$1"
  local frontend_dir="$2"
  local package_manager="$3"
  local backend_test=""
  local frontend_test=""

  if [[ -n "$backend_dir" && -f "$TARGET_ROOT/$backend_dir/pom.xml" ]]; then
    if [[ -x "$TARGET_ROOT/$backend_dir/mvnw" ]]; then
      backend_test="cd $backend_dir && ./mvnw test"
    else
      backend_test="cd $backend_dir && mvn test"
    fi
  elif [[ -f "$TARGET_ROOT/pom.xml" ]]; then
    if [[ -x "$TARGET_ROOT/mvnw" ]]; then
      backend_test="./mvnw test"
    else
      backend_test="mvn test"
    fi
  elif [[ -f "$TARGET_ROOT/go.mod" ]]; then
    backend_test="go test ./..."
  elif [[ -f "$TARGET_ROOT/composer.json" ]]; then
    backend_test="vendor/bin/phpunit"
  fi

  if [[ -n "$frontend_dir" && -f "$TARGET_ROOT/$frontend_dir/package.json" ]]; then
    if grep -Eq '"build"[[:space:]]*:' "$TARGET_ROOT/$frontend_dir/package.json"; then
      frontend_test="cd $frontend_dir && $package_manager run build"
    elif grep -Eq '"test"[[:space:]]*:' "$TARGET_ROOT/$frontend_dir/package.json"; then
      frontend_test="cd $frontend_dir && $package_manager test"
    fi
  elif [[ -f "$TARGET_ROOT/package.json" ]]; then
    if grep -Eq '"build"[[:space:]]*:' "$TARGET_ROOT/package.json"; then
      frontend_test="$package_manager run build"
    elif grep -Eq '"test"[[:space:]]*:' "$TARGET_ROOT/package.json"; then
      frontend_test="$package_manager test"
    fi
  fi

  if [[ -n "$backend_test" && -n "$frontend_test" ]]; then
    if [[ "$backend_dir" == "." || -z "$backend_dir" ]]; then
      printf '%s && %s\n' "$backend_test" "$frontend_test"
    else
      printf '%s && cd .. && %s\n' "$backend_test" "$frontend_test"
    fi
  elif [[ -n "$backend_test" ]]; then
    printf '%s\n' "$backend_test"
  elif [[ -n "$frontend_test" ]]; then
    printf '%s\n' "$frontend_test"
  fi
}

yes_no() {
  [[ "$1" -eq 1 ]] && printf '是' || printf '否'
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --write)
      WRITE=1
      shift
      ;;
    --name)
      [[ "${2:-}" ]] || fail "--name requires a value"
      PROJECT_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      [[ -z "${TARGET_ARG:-}" ]] || fail "Only one project-root is allowed"
      TARGET_ARG="$1"
      shift
      ;;
  esac
done

if [[ -n "${TARGET_ARG:-}" ]]; then
  [[ -d "$TARGET_ARG" ]] || fail "Project root does not exist: $TARGET_ARG"
  TARGET_ROOT="$(cd "$TARGET_ARG" && pwd)"
fi

PROJECT_NAME="${PROJECT_NAME:-$(basename "$TARGET_ROOT")}"

HAS_POM=0
HAS_GRADLE=0
HAS_SPRING_BOOT=0
HAS_MYBATIS=0
HAS_MYBATIS_PLUS=0
HAS_FLYWAY=0
HAS_MYSQL=0
HAS_REDIS=0
HAS_NODE=0
HAS_VUE3=0
HAS_REACT=0
HAS_VITE=0
HAS_ELEMENT_PLUS=0
HAS_ANTD=0
HAS_GO=0
HAS_GIN=0
HAS_PHP=0
HAS_LARAVEL=0
HAS_THINKPHP=0
HAS_DOCKER=0
HAS_OPENAPI=0

contains_file pom.xml && HAS_POM=1
contains_file build.gradle && HAS_GRADLE=1
contains_file build.gradle.kts && HAS_GRADLE=1
contains_file package.json && HAS_NODE=1
[[ -f "$TARGET_ROOT/go.mod" ]] && HAS_GO=1
contains_file composer.json && HAS_PHP=1

if [[ "$HAS_POM" -eq 1 || "$HAS_GRADLE" -eq 1 ]]; then
  grep_project "spring-boot" --include pom.xml --include build.gradle --include build.gradle.kts && HAS_SPRING_BOOT=1
  grep_project "mybatis" --include pom.xml --include build.gradle --include build.gradle.kts && HAS_MYBATIS=1
  grep_project "mybatis-plus" --include pom.xml --include build.gradle --include build.gradle.kts && HAS_MYBATIS_PLUS=1
  grep_project "flyway" --include pom.xml --include build.gradle --include build.gradle.kts && HAS_FLYWAY=1
  grep_project "mysql-connector" --include pom.xml --include build.gradle --include build.gradle.kts && HAS_MYSQL=1
  grep_project "(data-redis|spring-boot-starter-redis|jedis|lettuce)" --include pom.xml --include build.gradle --include build.gradle.kts && HAS_REDIS=1
  grep_project "(springdoc|swagger|knife4j)" --include pom.xml --include build.gradle --include build.gradle.kts && HAS_OPENAPI=1
fi

if [[ "$HAS_NODE" -eq 1 ]]; then
  grep_project '"vue"[[:space:]]*:' --include package.json && HAS_VUE3=1
  grep_project '"react"[[:space:]]*:' --include package.json && HAS_REACT=1
  grep_project '"vite"[[:space:]]*:' --include package.json && HAS_VITE=1
  grep_project '"element-plus"[[:space:]]*:' --include package.json && HAS_ELEMENT_PLUS=1
  grep_project '("antd"|"ant-design-vue")[[:space:]]*:' --include package.json && HAS_ANTD=1
fi

if [[ "$HAS_GO" -eq 1 ]]; then
  grep_project 'github.com/gin-gonic/gin' --include go.mod && HAS_GIN=1
  grep_project 'mysql' --include go.mod && HAS_MYSQL=1
  grep_project 'redis' --include go.mod && HAS_REDIS=1
fi

if [[ "$HAS_PHP" -eq 1 ]]; then
  grep_project 'laravel/framework' --include composer.json && HAS_LARAVEL=1
  grep_project 'topthink/framework' --include composer.json && HAS_THINKPHP=1
fi

if find "$TARGET_ROOT" -maxdepth 3 \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' -o -name 'compose.yml' -o -name 'compose.yaml' -o -name 'Dockerfile' \) -print -quit 2>/dev/null | grep -q .; then
  HAS_DOCKER=1
fi

BACKEND_DIR="$(first_dir_with_file pom.xml || true)"
if [[ -z "$BACKEND_DIR" && "$HAS_GO" -eq 1 ]]; then
  BACKEND_DIR="."
elif [[ -z "$BACKEND_DIR" && "$HAS_PHP" -eq 1 ]]; then
  BACKEND_DIR="$(first_dir_with_file composer.json || true)"
fi

FRONTEND_DIR="$(first_dir_with_file package.json || true)"
PACKAGE_MANAGER="$(detect_node_package_manager "$FRONTEND_DIR")"

PROFILE="minimal"
if [[ "$HAS_SPRING_BOOT" -eq 1 && "$HAS_NODE" -eq 1 ]]; then
  PROFILE="fullstack-admin"
elif [[ "$HAS_SPRING_BOOT" -eq 1 ]]; then
  PROFILE="java-springboot"
elif [[ "$HAS_VUE3" -eq 1 ]]; then
  PROFILE="vue3-admin"
elif [[ "$HAS_REACT" -eq 1 ]]; then
  PROFILE="react-admin"
elif [[ "$HAS_GIN" -eq 1 || "$HAS_GO" -eq 1 ]]; then
  PROFILE="go-gin"
elif [[ "$HAS_PHP" -eq 1 ]]; then
  PROFILE="php"
fi

PROJECT_TEST_COMMAND="$(detect_test_command "$BACKEND_DIR" "$FRONTEND_DIR" "$PACKAGE_MANAGER" || true)"

printf '项目名称: %s\n' "$PROJECT_NAME"
printf '项目目录: %s\n' "$TARGET_ROOT"
printf '推荐 profile: %s\n' "$PROFILE"
printf '后端目录: %s\n' "${BACKEND_DIR:-待确认}"
printf '前端目录: %s\n' "${FRONTEND_DIR:-待确认}"
printf '包管理器: %s\n' "$PACKAGE_MANAGER"
printf 'Spring Boot: %s\n' "$(yes_no "$HAS_SPRING_BOOT")"
printf 'Vue3: %s\n' "$(yes_no "$HAS_VUE3")"
printf 'React: %s\n' "$(yes_no "$HAS_REACT")"
printf 'Go: %s\n' "$(yes_no "$HAS_GO")"
printf 'PHP: %s\n' "$(yes_no "$HAS_PHP")"
printf 'MySQL: %s\n' "$(yes_no "$HAS_MYSQL")"
printf 'Redis: %s\n' "$(yes_no "$HAS_REDIS")"
printf 'Docker: %s\n' "$(yes_no "$HAS_DOCKER")"
[[ -n "$PROJECT_TEST_COMMAND" ]] && printf '推荐测试命令: %s\n' "$PROJECT_TEST_COMMAND"

if [[ "$WRITE" -eq 1 ]]; then
  mkdir -p "$TARGET_ROOT/.ai-control"
  PROJECT_ACCESS_CONTROL_MODE="${ACCESS_CONTROL_MODE:-pending}"
  if [[ -f "$TARGET_ROOT/.ai-control/project.env" ]]; then
    existing_access_control="$(awk -F= '/^ACCESS_CONTROL_MODE=/ { print $2; exit }' "$TARGET_ROOT/.ai-control/project.env" | tr -d "'\"" || true)"
    PROJECT_ACCESS_CONTROL_MODE="${existing_access_control:-$PROJECT_ACCESS_CONTROL_MODE}"
  fi
  cat > "$TARGET_ROOT/.ai-control/project.env" <<EOF
# 本文件由 scripts/detect-project-profile.sh 生成。
# 只记录项目画像和推荐配置，不放密钥。

PROJECT_NAME='$PROJECT_NAME'
PROJECT_ROOT='$TARGET_ROOT'
AI_CONTROL_PROFILE='$PROFILE'
BACKEND_DIR='${BACKEND_DIR:-}'
FRONTEND_DIR='${FRONTEND_DIR:-}'
PACKAGE_MANAGER='$PACKAGE_MANAGER'
PROJECT_TEST_COMMAND='${PROJECT_TEST_COMMAND:-}'
ACCESS_CONTROL_MODE='$PROJECT_ACCESS_CONTROL_MODE'

HAS_SPRING_BOOT=$HAS_SPRING_BOOT
HAS_MYBATIS=$HAS_MYBATIS
HAS_MYBATIS_PLUS=$HAS_MYBATIS_PLUS
HAS_FLYWAY=$HAS_FLYWAY
HAS_NODE=$HAS_NODE
HAS_VUE3=$HAS_VUE3
HAS_REACT=$HAS_REACT
HAS_VITE=$HAS_VITE
HAS_ELEMENT_PLUS=$HAS_ELEMENT_PLUS
HAS_ANTD=$HAS_ANTD
HAS_GO=$HAS_GO
HAS_GIN=$HAS_GIN
HAS_PHP=$HAS_PHP
HAS_LARAVEL=$HAS_LARAVEL
HAS_THINKPHP=$HAS_THINKPHP
HAS_MYSQL=$HAS_MYSQL
HAS_REDIS=$HAS_REDIS
HAS_DOCKER=$HAS_DOCKER
HAS_OPENAPI=$HAS_OPENAPI
EOF

  cat > "$TARGET_ROOT/.ai-control/project-profile.md" <<EOF
# 项目画像

## 基本信息

- 项目名称：$PROJECT_NAME
- 项目目录：$TARGET_ROOT
- 推荐 profile：$PROFILE
- 后端目录：${BACKEND_DIR:-待确认}
- 前端目录：${FRONTEND_DIR:-待确认}
- 包管理器：$PACKAGE_MANAGER

## 技术栈识别

| 项目 | 结果 |
|------|------|
| Spring Boot | $(yes_no "$HAS_SPRING_BOOT") |
| MyBatis | $(yes_no "$HAS_MYBATIS") |
| MyBatis-Plus | $(yes_no "$HAS_MYBATIS_PLUS") |
| Flyway | $(yes_no "$HAS_FLYWAY") |
| Vue3 | $(yes_no "$HAS_VUE3") |
| React | $(yes_no "$HAS_REACT") |
| Vite | $(yes_no "$HAS_VITE") |
| Element Plus | $(yes_no "$HAS_ELEMENT_PLUS") |
| Ant Design | $(yes_no "$HAS_ANTD") |
| Go | $(yes_no "$HAS_GO") |
| Gin | $(yes_no "$HAS_GIN") |
| PHP | $(yes_no "$HAS_PHP") |
| Laravel | $(yes_no "$HAS_LARAVEL") |
| ThinkPHP | $(yes_no "$HAS_THINKPHP") |
| MySQL | $(yes_no "$HAS_MYSQL") |
| Redis | $(yes_no "$HAS_REDIS") |
| Docker | $(yes_no "$HAS_DOCKER") |
| OpenAPI/Swagger | $(yes_no "$HAS_OPENAPI") |

## 推荐验证命令

\`\`\`bash
${PROJECT_TEST_COMMAND:-# 待确认：未识别到可直接运行的测试或构建命令}
\`\`\`

## 使用说明

- 本文件是项目适配层，不是业务需求文档。
- 业务规则仍以 \`openspec/\`、\`CONTEXT.md\` 和用户确认内容为准。
- 如果识别结果不准确，直接修改 \`.ai-control/project.env\` 和本文件即可。
- \`ACCESS_CONTROL_MODE\` 默认是 \`pending\`；运行 \`bash scripts/ai-dev.sh init\` 后可改为 \`local\`、\`external\` 或 \`none\`。
EOF

  printf '[WRITE] .ai-control/project.env\n'
  printf '[WRITE] .ai-control/project-profile.md\n'
fi
