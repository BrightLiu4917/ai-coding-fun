#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"

header()  { printf "\n${BOLD}${CYAN}%s${RESET}\n" "$*"; }
step()    { printf "${GREEN}  ✔${RESET} %s\n" "$*"; }
warn()    { printf "${YELLOW}  !${RESET} %s\n" "$*"; }
error()   { printf "${RED}  ✘${RESET} %s\n" "$*" >&2; }
prompt()  { printf "${BOLD}  ›${RESET} %s: " "$*"; }
info()    { printf "    %s\n" "$*"; }

read_input() {
  local __var="$1"
  local value=""
  if IFS= read -r value; then
    printf -v "$__var" '%s' "$value"
  else
    printf -v "$__var" '%s' ""
  fi
}

replace_or_append_env() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp

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

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_node_command() {
  local project_dir="$1"
  local dir="$2"
  local package_file="$project_dir/$dir/package.json"
  local runner="npm"

  [[ -f "$package_file" ]] || return 0

  if [[ -f "$project_dir/$dir/pnpm-lock.yaml" ]]; then
    runner="pnpm"
  elif [[ -f "$project_dir/$dir/yarn.lock" ]]; then
    runner="yarn"
  fi

  if grep -Eq '"build"[[:space:]]*:' "$package_file"; then
    printf 'cd %s && %s run build\n' "$dir" "$runner"
  elif grep -Eq '"test"[[:space:]]*:' "$package_file"; then
    printf 'cd %s && %s test\n' "$dir" "$runner"
  fi
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

is_yes() {
  case "$(lower "${1:-}")" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║     AI 全栈控制系统 — 交互式安装向导          ║"
echo "  ╚══════════════════════════════════════════════╝"

PROJECT_DIR=""
PROJECT_NAME=""
IS_FULLSTACK=""
IS_VUE=""
IS_REACT=""
IS_JAVA=""
IS_SPRING_BOOT=""
IS_GUPO=""
USE_DEEPV4=""
BACKEND_ONLY=""

header "第一步：目标项目信息"

while true; do
  prompt "请输入目标项目根目录的绝对路径"
  read_input PROJECT_DIR
  PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"

  if [[ -z "$PROJECT_DIR" ]]; then
    warn "路径不能为空"
    continue
  fi

  if [[ ! -d "$PROJECT_DIR" ]]; then
    warn "目录不存在: $PROJECT_DIR"
    prompt "是否自动创建? (y/N)"
    read_input create_dir
    if is_yes "$create_dir"; then
      mkdir -p "$PROJECT_DIR"
      step "已创建目录: $PROJECT_DIR"
    else
      continue
    fi
  fi

  PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
    warn "无法进入目录: $PROJECT_DIR"
    continue
  }

  if [[ "$PROJECT_DIR" == "$ROOT" ]]; then
    error "不能安装到控制系统仓库自身"
    continue
  fi

  break
done

prompt "项目名称 (沿用目录名按回车)"
read_input PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_DIR")}"

step "目标: $PROJECT_DIR ($PROJECT_NAME)"

header "第二步：自动检测技术栈"

DETECTED_JAVA=0
DETECTED_NODE=0
DETECTED_VUE=0
DETECTED_REACT=0
DETECTED_SPRING_BOOT=0
DETECTED_MAVEN=0
DETECTED_NPM=0
DETECTED_PNPM=0

if find "$PROJECT_DIR" -maxdepth 3 -name pom.xml -print -quit 2>/dev/null | grep -q .; then
  DETECTED_JAVA=1
  DETECTED_MAVEN=1
  step "检测到: Java / Maven (pom.xml)"

  if grep -R "<artifactId>spring-boot-starter-parent</artifactId>" "$PROJECT_DIR" --include pom.xml >/dev/null 2>&1; then
    DETECTED_SPRING_BOOT=1
    step "检测到: Spring Boot"
  fi
fi

if find "$PROJECT_DIR" -maxdepth 3 -name package.json -print -quit 2>/dev/null | grep -q .; then
  DETECTED_NODE=1
  step "检测到: Node.js (package.json)"

  if grep -R '"vue"' "$PROJECT_DIR" --include package.json >/dev/null 2>&1; then
    DETECTED_VUE=1
    step "检测到: Vue"
  fi

  if grep -R '"react"' "$PROJECT_DIR" --include package.json >/dev/null 2>&1; then
    DETECTED_REACT=1
    step "检测到: React"
  fi

  if find "$PROJECT_DIR" -maxdepth 3 -name pnpm-lock.yaml -print -quit 2>/dev/null | grep -q .; then
    DETECTED_PNPM=1
    step "检测到: pnpm"
  elif find "$PROJECT_DIR" -maxdepth 3 -name package-lock.json -print -quit 2>/dev/null | grep -q .; then
    DETECTED_NPM=1
    step "检测到: npm"
  fi
fi

if [[ "$DETECTED_JAVA" -eq 0 && "$DETECTED_NODE" -eq 0 ]]; then
  warn "未检测到 pom.xml 或 package.json，这是一个空项目或非标准项目"
  warn "控制系统仍可安装，但规则文档中的技术栈约束需要你自己判断"
fi

header "第三步：项目类型确认"

if [[ "$DETECTED_JAVA" -eq 1 && "$DETECTED_NODE" -eq 1 ]]; then
  IS_FULLSTACK="y"
  step "检测到前后端代码，默认视为全栈项目"

elif [[ "$DETECTED_JAVA" -eq 1 ]]; then
  prompt "这是纯后端项目吗? (Y/n)"
  read_input BACKEND_ONLY
  BACKEND_ONLY="${BACKEND_ONLY:-y}"
  if [[ "$(lower "$BACKEND_ONLY")" == "n" ]]; then
    IS_FULLSTACK="y"
    warn "将安装全栈 agent，如有不需要的可安装后手动删除"
  else
    IS_FULLSTACK="n"
  fi

elif [[ "$DETECTED_NODE" -eq 1 ]]; then
  prompt "这是纯前端项目吗? (Y/n)"
  read_input BACKEND_ONLY
  BACKEND_ONLY="${BACKEND_ONLY:-y}"
  IS_FULLSTACK="n"

else
  prompt "这是全栈项目吗? (y/N)"
  read_input IS_FULLSTACK
  IS_FULLSTACK="${IS_FULLSTACK:-n}"
fi

if [[ "$DETECTED_SPRING_BOOT" -eq 1 ]]; then
  IS_JAVA="y"
  IS_SPRING_BOOT="y"
elif [[ "$DETECTED_JAVA" -eq 1 ]]; then
  prompt "是 Spring Boot 项目吗? (Y/n)"
  read_input ans
  IS_SPRING_BOOT="${ans:-y}"
  IS_JAVA="y"
elif is_yes "$IS_FULLSTACK"; then
  prompt "后端是 Java/Spring Boot 吗? (Y/n)"
  read_input ans
  IS_SPRING_BOOT="${ans:-y}"
  IS_JAVA="${ans:-y}"
fi

if [[ "$DETECTED_VUE" -eq 1 ]]; then
  IS_VUE="y"
elif [[ "$DETECTED_REACT" -eq 1 ]]; then
  IS_REACT="y"
elif is_yes "$IS_FULLSTACK"; then
  prompt "前端框架是 Vue(v) 还是 React(r)? (v/r)"
  read_input ans
  case "$(lower "$ans")" in
    v*) IS_VUE="y" ;;
    r*) IS_REACT="y" ;;
    *) IS_VUE="n"; IS_REACT="n"; warn "不指定框架，前端 agent 按通用处理" ;;
  esac
fi

if [[ "$DETECTED_SPRING_BOOT" -eq 1 || "$(lower "${IS_SPRING_BOOT:-}")" == "y" ]]; then
  warn "只有确认项目使用 gupo 封装、目录、响应体、分页和异常体系时才选择 y。"
  prompt "是 gupo 公司的项目吗? (y/N)"
  read_input IS_GUPO
  IS_GUPO="${IS_GUPO:-n}"
fi

header "第四步：deepv4 配置"

prompt "需要 deepv4 二审吗? (y/N)"
read_input USE_DEEPV4
USE_DEEPV4="${USE_DEEPV4:-n}"

header "第五步：确认安装方案"

echo ""
echo "  ┌─────────────────────────────────────────────┐"
printf  "  │  目标项目    %-30s │\n" "$PROJECT_NAME"
printf  "  │  项目路径    %-30s │\n" "$PROJECT_DIR"
echo   "  ├─────────────────────────────────────────────┤"
printf  "  │  Java        %-30s │\n" "$(is_yes "${IS_JAVA:-n}" && echo "是" || echo "否")"
printf  "  │  Spring Boot %-30s │\n" "$(is_yes "${IS_SPRING_BOOT:-n}" && echo "是" || echo "否")"
printf  "  │  Vue         %-30s │\n" "$(is_yes "${IS_VUE:-n}" && echo "是" || echo "否")"
printf  "  │  React       %-30s │\n" "$(is_yes "${IS_REACT:-n}" && echo "是" || echo "否")"
printf  "  │  全栈        %-30s │\n" "$(is_yes "${IS_FULLSTACK:-n}" && echo "是" || echo "否")"
printf  "  │  gupo 专用   %-30s │\n" "$(is_yes "${IS_GUPO:-n}" && echo "是" || echo "否")"
printf  "  │  deepv4 二审 %-30s │\n" "$(is_yes "${USE_DEEPV4:-n}" && echo "是" || echo "否")"
echo   "  └─────────────────────────────────────────────┘"

prompt "确认安装? (Y/n)"
read_input confirm
if [[ -n "$confirm" ]] && ! is_yes "$confirm"; then
  echo ""
  info "已取消，没有修改任何文件。"
  exit 0
fi

header "第六步：正在安装控制系统"

INSTALL_ARGS=()

if is_yes "${IS_GUPO:-n}"; then
  PROFILE="gupo"
elif is_yes "${IS_SPRING_BOOT:-n}" && { is_yes "${IS_FULLSTACK:-n}" || is_yes "${IS_VUE:-n}" || is_yes "${IS_REACT:-n}"; }; then
  PROFILE="fullstack-admin"
elif is_yes "${IS_SPRING_BOOT:-n}"; then
  PROFILE="java-springboot"
elif is_yes "${IS_VUE:-n}"; then
  PROFILE="vue3-admin"
elif is_yes "${IS_REACT:-n}"; then
  PROFILE="react-admin"
else
  PROFILE="default"
fi

INSTALL_ARGS+=(--profile "$PROFILE")

GIT_REPO=0
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_REPO=1
  INSTALL_ARGS+=(--backup)
else
  warn "目标项目不在 git 仓库中，将使用 --backup 避免静默覆盖。建议安装后 git init。"
  INSTALL_ARGS+=(--backup)
fi

"$ROOT/scripts/install-to-project.sh" "${INSTALL_ARGS[@]}" "$PROJECT_DIR"

step "控制系统文件安装完成"

header "第七步：初始化项目上下文"

INIT_ARGS=(--name "$PROJECT_NAME")
if [[ -f "$PROJECT_DIR/openspec/project.md" || -f "$PROJECT_DIR/CONTEXT.md" ]]; then
  INIT_ARGS+=(--force)
fi

"$ROOT/scripts/init-project.sh" "${INIT_ARGS[@]}" "$PROJECT_DIR"

step "项目上下文初始化完成"

header "第八步：配置 Codegen Adapter"

mkdir -p "$PROJECT_DIR/.agent"

if is_yes "${IS_GUPO:-n}" && [[ ! -f "$PROJECT_DIR/.agent/codegen.toml" ]]; then
  cat > "$PROJECT_DIR/.agent/codegen.toml" <<'TOML'
[java.springboot.crud]
adapter = "gupo"
TOML
  step "已创建 .agent/codegen.toml (adapter = gupo)"
elif is_yes "${IS_SPRING_BOOT:-n}" && ! is_yes "${IS_GUPO:-n}"; then
  warn "非 gupo Spring Boot 项目不需要 codegen.toml"
  warn "CRUD 链路会走通用 adapter 预览 → 用户确认 → 手写实现"
fi

header "第九步：配置测试和 deepv4"

PROJECT_ENV_FILE="$PROJECT_DIR/.agent/project.env"
if [[ ! -f "$PROJECT_ENV_FILE" ]]; then
  cp "$ROOT/templates/project.env.example" "$PROJECT_ENV_FILE"
fi

TEST_COMMAND=""
if [[ -f "$PROJECT_DIR/api/pom.xml" && -f "$PROJECT_DIR/vue/package.json" ]]; then
  if [[ -x "$PROJECT_DIR/api/mvnw" ]]; then
    BACKEND_TEST="cd api && ./mvnw test"
  else
    BACKEND_TEST="cd api && mvn test"
  fi

  FRONTEND_TEST="$(detect_node_command "$PROJECT_DIR" "vue")"

  if [[ -n "$FRONTEND_TEST" ]]; then
    TEST_COMMAND="${BACKEND_TEST} && cd .. && ${FRONTEND_TEST}"
  else
    TEST_COMMAND="${BACKEND_TEST}"
  fi
elif is_yes "${IS_SPRING_BOOT:-n}"; then
  if find "$PROJECT_DIR" -maxdepth 3 -name mvnw -perm -111 -print -quit 2>/dev/null | grep -q .; then
    TEST_COMMAND="./mvnw test"
  else
    TEST_COMMAND="mvn test"
  fi
elif [[ "$DETECTED_NODE" -eq 1 ]]; then
  if [[ "$DETECTED_PNPM" -eq 1 ]]; then
    if grep -Eq '"build"[[:space:]]*:' "$PROJECT_DIR/package.json"; then
      TEST_COMMAND="pnpm run build"
    else
      TEST_COMMAND="pnpm test"
    fi
  else
    if grep -Eq '"build"[[:space:]]*:' "$PROJECT_DIR/package.json"; then
      TEST_COMMAND="npm run build"
    else
      TEST_COMMAND="npm test"
    fi
  fi
fi

if [[ -n "$TEST_COMMAND" ]]; then
  replace_or_append_env "$PROJECT_ENV_FILE" "PROJECT_TEST_COMMAND" "'$TEST_COMMAND'"
  if [[ -f "$PROJECT_DIR/.ai-control/project.env" ]]; then
    replace_or_append_env "$PROJECT_DIR/.ai-control/project.env" "PROJECT_TEST_COMMAND" "'$TEST_COMMAND'"
  fi
fi

if is_yes "${USE_DEEPV4:-n}"; then
  DEEPV4_ENV_FILE="$PROJECT_DIR/.agent/deepv4.env"
  if [[ ! -f "$DEEPV4_ENV_FILE" ]]; then
    cp "$ROOT/templates/deepv4.env.example" "$DEEPV4_ENV_FILE"
  fi
  warn "请在 .agent/deepv4.env 中填入真实的 DEEPV4_BASE_URL 和 DEEPV4_API_KEY"
fi

if ! grep -q '^\.agent/' "$PROJECT_DIR/.gitignore" 2>/dev/null; then
  echo '.agent/' >> "$PROJECT_DIR/.gitignore"
  step "已将 .agent/ 加入 .gitignore"
fi

step "测试和 deepv4 配置完成"

header "第十步：运行验证"

FAIL=0

if [[ -x "$PROJECT_DIR/scripts/agent-check.sh" ]]; then
  if "$PROJECT_DIR/scripts/agent-check.sh"; then
    step "agent-check 通过"
  else
    warn "agent-check 有警告，不影响安装"
  fi
fi

if [[ -x "$PROJECT_DIR/scripts/docs-link-check.sh" ]]; then
  "$PROJECT_DIR/scripts/docs-link-check.sh" && step "docs-link-check 通过" || warn "docs-link-check 有警告"
fi

if [[ -x "$PROJECT_DIR/scripts/check-project-ready.sh" ]]; then
  "$PROJECT_DIR/scripts/check-project-ready.sh" && step "check-project-ready 通过" || warn "check-project-ready 有警告"
fi

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║         🎉  安装完成！                        ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
printf "  ${GREEN}目标项目${RESET}   %s\n" "$PROJECT_DIR"
echo ""

printf "  ${BOLD}现在可以做的事：${RESET}\n"
echo "  ─────────────────────────────────────────"
echo "  - 小白初始化项目卡片："
echo "     bash scripts/ai-dev.sh init"
echo ""

if is_yes "${IS_GUPO:-n}"; then
  echo "  - codegen adapter 已配置为 gupo"
  echo "     vim .agent/codegen.toml"
  echo ""
fi

if is_yes "${USE_DEEPV4:-n}"; then
  echo "  - deepv4 二审已启用，请配置 key："
  echo "     vim .agent/deepv4.env"
  echo ""
fi

echo "  - 创建第一个 OpenSpec change："
echo "     bash scripts/ai-dev.sh feature add-my-feature"
echo ""

echo "  - 提交到 git："
echo "     git add ."
echo "     git commit -m 'chore: install ai-fullstack-control-system'"
echo ""

printf "  ${BOLD}常用命令：${RESET}\n"
echo "  ─────────────────────────────────────────"
echo "  bash scripts/agent-check.sh                     # 校验 agent 结构"
echo "  bash scripts/ai-dev.sh next                     # 查看下一步建议"
echo "  bash scripts/openspec-check.sh <change-dir>     # 校验 OpenSpec change"
echo "  bash scripts/run-tests.sh                       # 统一测试入口"
echo "  bash scripts/openspec-conflict-check.sh         # 多 change 冲突检测"
echo "  bash scripts/check-project-ready.sh             # 检查项目接入完整性"
echo ""
