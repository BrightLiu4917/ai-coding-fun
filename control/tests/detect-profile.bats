#!/usr/bin/env bats
# 回归：detect-project-profile.sh --write 必须保留用户手改值（合并式更新）

load test_helper

setup() {
  make_test_project >/dev/null
}

teardown() {
  destroy_test_project
}

@test "首次 --write 生成 project.env" {
  run bash "$SCRIPTS_DIR/detect-project-profile.sh" --write "$TEST_PROJECT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_PROJECT/.ai-control/project.env" ]
  grep -q "^ACCESS_CONTROL_MODE='pending'" "$TEST_PROJECT/.ai-control/project.env"
}

@test "二次 --write 保留用户手改的测试命令和访问控制模式" {
  bash "$SCRIPTS_DIR/detect-project-profile.sh" --write "$TEST_PROJECT" >/dev/null
  env_file="$TEST_PROJECT/.ai-control/project.env"
  sed -i.bak "s|^PROJECT_TEST_COMMAND=.*|PROJECT_TEST_COMMAND='npm run test -- --grep \"x y\"'|" "$env_file"
  sed -i.bak "s|^ACCESS_CONTROL_MODE=.*|ACCESS_CONTROL_MODE='local'|" "$env_file"
  rm -f "$env_file.bak"

  bash "$SCRIPTS_DIR/detect-project-profile.sh" --write "$TEST_PROJECT" >/dev/null

  grep -q 'npm run test -- --grep "x y"' "$env_file"
  grep -q "^ACCESS_CONTROL_MODE='local'" "$env_file"
}

@test "含引号的值写入后可安全 source 且往返一致" {
  bash "$SCRIPTS_DIR/detect-project-profile.sh" --write "$TEST_PROJECT" >/dev/null
  env_file="$TEST_PROJECT/.ai-control/project.env"
  # 手工塞入含单引号的测试命令（模拟用户编辑）
  python3 - "$env_file" <<'PY'
import sys, re
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
value = "echo it's fine"
escaped = value.replace("'", "'\\''")
text = re.sub(r"^PROJECT_TEST_COMMAND=.*$", f"PROJECT_TEST_COMMAND='{escaped}'", text, flags=re.M)
open(path, "w", encoding="utf-8").write(text)
PY
  bash "$SCRIPTS_DIR/detect-project-profile.sh" --write "$TEST_PROJECT" >/dev/null
  run bash -c "source '$env_file' && printf '%s' \"\$PROJECT_TEST_COMMAND\""
  [ "$status" -eq 0 ]
  [ "$output" = "echo it's fine" ]
}
