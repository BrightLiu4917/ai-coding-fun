#!/usr/bin/env bats
# 回归：prepare-review.sh 的敏感文件排除、密钥拦截和 diff 截断（兼容旧 DEEPV4_* 变量在此一并回归）

load test_helper

setup() {
  make_test_project prepare-review.sh summarize-log.sh >/dev/null
  echo "base" > "$TEST_PROJECT/src/app.java"
  echo "DB_HOST=old" > "$TEST_PROJECT/.env"
  echo "x: 1" > "$TEST_PROJECT/application-prod.yml"
  mkdir -p "$TEST_PROJECT/config/deep"
  echo "y: 1" > "$TEST_PROJECT/config/deep/app-prod.yaml"
  git_commit_all "$TEST_PROJECT"
  OUT_DIR="$(mktemp -d)"
}

teardown() {
  destroy_test_project
  rm -rf "$OUT_DIR"
}

prepare() {
  bash "$TEST_PROJECT/.ai-control/control/scripts/prepare-review.sh" "$@"
}

@test "根目录与嵌套目录的敏感文件变更不进入外发内容" {
  echo 'public class A {}' >> "$TEST_PROJECT/src/app.java"
  echo "DB_PASSWORD=supersecret123" >> "$TEST_PROJECT/.env"
  echo "password: 'prod-secret-999'" >> "$TEST_PROJECT/application-prod.yml"
  echo "password: 'nested-secret-888'" >> "$TEST_PROJECT/config/deep/app-prod.yaml"

  run prepare "$OUT_DIR/out.md"
  [ "$status" -eq 0 ]
  ! grep -q 'supersecret123' "$OUT_DIR/out.md"
  ! grep -q 'prod-secret-999' "$OUT_DIR/out.md"
  ! grep -q 'nested-secret-888' "$OUT_DIR/out.md"
  grep -q 'public class A' "$OUT_DIR/out.md"
}

@test "代码中的密钥字面量导致中止且输出文件被清除" {
  echo 'String apiKey = "sk-abcdef1234567890abcdef";' >> "$TEST_PROJECT/src/app.java"
  run prepare "$OUT_DIR/out.md"
  [ "$status" -eq 2 ]
  [ ! -f "$OUT_DIR/out.md" ]
}

@test "旧变量 DEEPV4_ALLOW_SECRETS=1 兼容放行" {
  echo 'String apiKey = "sk-abcdef1234567890abcdef";' >> "$TEST_PROJECT/src/app.java"
  DEEPV4_ALLOW_SECRETS=1 run prepare "$OUT_DIR/out.md"
  [ "$status" -eq 0 ]
  [ -f "$OUT_DIR/out.md" ]
}

@test "超过上限的 diff 被截断并带标记" {
  python3 -c "print('int padVar = 1;\n' * 500)" >> "$TEST_PROJECT/src/app.java"
  DEEPV4_DIFF_MAX_BYTES=1000 run prepare "$OUT_DIR/out.md"
  [ "$status" -eq 0 ]
  grep -q '# TRUNCATED' "$OUT_DIR/out.md"
}

@test "无未跟踪文件时脚本不被 pipefail 打断" {
  echo 'public class B {}' >> "$TEST_PROJECT/src/app.java"
  run prepare "$OUT_DIR/out.md"
  [ "$status" -eq 0 ]
  grep -q 'REVIEW_INPUT=' <<<"$output"
}
