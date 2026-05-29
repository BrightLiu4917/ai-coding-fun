#!/usr/bin/env bash
set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: $0 <api-contract-file>"
  exit 1
fi

fail=0
api_path_count=0
method_count=0

require_heading_any() {
  local label="$1"
  local pattern="$2"
  if ! grep -Eq "^##[[:space:]]+($pattern)$" "$FILE"; then
    echo "[FAIL] Missing section: $label"
    fail=1
  fi
}

require_heading_any "接口说明" "接口|接口清单|接口说明|接口定义"
require_heading_any "请求参数" "请求|请求参数|请求说明"
require_heading_any "响应参数" "响应|响应参数|响应说明"
require_heading_any "兼容性" "兼容性"

while IFS= read -r method; do
  method_count=$((method_count + 1))
  case "$method" in
    GET|POST) ;;
    PUT|DELETE|PATCH)
      echo "[FAIL] Forbidden HTTP Method: $method. Only GET and POST are allowed."
      fail=1
      ;;
  esac
done < <(grep -Eo '\b(GET|POST|PUT|DELETE|PATCH)\b' "$FILE" | sort -u || true)

while IFS= read -r path; do
  api_path_count=$((api_path_count + 1))
  path="${path//\`/}"

  if [[ ! "$path" =~ ^/(api/(admin|app)/v[0-9]+|openapi/app/v[0-9]+|innerapi/app/v[0-9]+)(/|$) ]]; then
    echo "[FAIL] API path prefix/version is invalid: $path"
    fail=1
  fi

  if [[ "$path" == *"{"* || "$path" == *"}"* ]]; then
    echo "[FAIL] Path parameter is forbidden: $path"
    fail=1
  fi

  if [[ "$path" =~ [A-Z_] ]]; then
    echo "[FAIL] API path must use lowercase kebab-case without uppercase or underscore: $path"
    fail=1
  fi
done < <(grep -Eo '`?/(api|openapi|innerapi)/[A-Za-z0-9_{}./:-]+`?' "$FILE" || true)

if [[ "$method_count" -eq 0 ]]; then
  echo "[FAIL] Missing HTTP Method. Use GET or POST."
  fail=1
fi

if [[ "$api_path_count" -eq 0 ]]; then
  echo "[FAIL] Missing API path."
  fail=1
fi

if [[ "$fail" -eq 1 ]]; then
  echo "API contract check failed."
  exit 2
fi

echo "API contract check passed."
