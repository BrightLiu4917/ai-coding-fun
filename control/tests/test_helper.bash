# 共享测试工具：为每个用例提供隔离的临时项目环境。

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/control/scripts"

# 创建一个带 git 仓库和 .ai-control 安装布局的临时项目。
# 用法: make_test_project <需要安装的脚本名...>
# 输出: 项目路径（同时导出 TEST_PROJECT）
make_test_project() {
  TEST_PROJECT="$(mktemp -d)/proj"
  mkdir -p "$TEST_PROJECT/.ai-control/control/scripts" "$TEST_PROJECT/src"
  local script
  for script in "$@"; do
    cp "$SCRIPTS_DIR/$script" "$TEST_PROJECT/.ai-control/control/scripts/"
  done
  git -C "$TEST_PROJECT" init -q
  git -C "$TEST_PROJECT" config user.email test@test.local
  git -C "$TEST_PROJECT" config user.name test
  printf '%s' "$TEST_PROJECT"
}

destroy_test_project() {
  [[ -n "${TEST_PROJECT:-}" && -d "$TEST_PROJECT" ]] && rm -rf "$(dirname "$TEST_PROJECT")"
  return 0
}

git_commit_all() {
  local project="$1" msg="${2:-init}"
  git -C "$project" add -A
  git -C "$project" commit -qm "$msg"
}
