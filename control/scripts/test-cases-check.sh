#!/usr/bin/env bash
set -euo pipefail

# 测试用例检查：test-cases.md 是设计阶段的验收契约。
# 默认校验：文件存在、至少一条用例、与影响范围闭环
#   - affected_apis 非 none  => 必须有异常流用例
#   - affected_pages 非 none => 必须有权限用例，且有空态或错误态用例
# --evidence（发布门禁用）：直接核对 JUnit 原始报告——
#   报告存在、无 failure/error，且每条非手动用例的 TC-ID 出现在测试名中。
#   不再依赖 test-cases.md 的状态列（报告即证据，无二手账本）。
#   手动用例不在此校验，执行结果由交付说明承载。

CHANGE_DIR=""
EVIDENCE=0
REPORT_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --evidence|--require-filled) EVIDENCE=1 ;;  # --require-filled 为旧名兼容
    *)
      if [[ -z "$CHANGE_DIR" ]]; then
        CHANGE_DIR="$arg"
      else
        REPORT_ARGS+=("$arg")
      fi
      ;;
  esac
done

if [[ -z "$CHANGE_DIR" || ! -d "$CHANGE_DIR" ]]; then
  echo "Usage: $0 [--evidence] openspec/changes/<change-id> [junit-报告目录 ...]" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
fi

PROPOSAL="$CHANGE_DIR/proposal.md"
CASES="$CHANGE_DIR/test-cases.md"
fail=0

error() {
  printf '[FAIL] %s\n' "$*"
  fail=1
}

has_scope_item() {
  local key="$1"
  local file="$2"
  [[ -f "$file" ]] || return 1
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key ":" { in_key=1; next }
    in_key && /^[[:space:]]*[a-zA-Z_]+:/ { in_key=0 }
    in_key && /^[[:space:]]*-[[:space:]]*/ {
      item=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", item)
      if (item != "" && item != "none") found=1
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

if [[ ! -f "$CASES" ]]; then
  error "缺少 test-cases.md；验收测试用例必须在设计阶段产出并随 change 确认"
  echo "Test cases check failed."
  exit 2
fi

case_rows="$(grep -cE '^\|[[:space:]]*TC-' "$CASES" || true)"
if [[ "$case_rows" -eq 0 ]]; then
  error "test-cases.md 没有任何用例行（用例ID 须以 TC- 开头）"
fi

if has_scope_item "affected_apis" "$PROPOSAL"; then
  if ! grep -q '异常流' "$CASES"; then
    error "affected_apis 非 none：必须包含异常流用例（参数错误、数据不存在、状态不允许）"
  fi
fi

if has_scope_item "affected_pages" "$PROPOSAL"; then
  if ! grep -q '权限' "$CASES"; then
    error "affected_pages 非 none：必须包含权限用例"
  fi
  if ! grep -Eq '空态|错误态' "$CASES"; then
    error "affected_pages 非 none：必须包含空态或错误态用例"
  fi
fi

# 全部用例均为"手动"时，没有自动化测试也就没有 JUnit 报告——豁免报告检查，
# 验收由交付说明中的手动验证结果承载（改文案/调样式类 lite 变更的常态）。
all_manual=0
auto_rows="$(grep -E '^\|[[:space:]]*TC-' "$CASES" | grep -cv '手动' || true)"
if [[ "$case_rows" -gt 0 && "$auto_rows" -eq 0 ]]; then
  all_manual=1
fi

if [[ "$EVIDENCE" -eq 1 && "$all_manual" -eq 1 ]]; then
  echo "全部用例为手动验证：跳过 JUnit 报告核对，验收结果须逐条写入交付说明。"
elif [[ "$EVIDENCE" -eq 1 ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    error "python3 is required for --evidence"
  else
    # 报告目录：显式传参优先，否则自动搜索常见位置
    REPORT_PATHS=("${REPORT_ARGS[@]:-}")
    if [[ "${#REPORT_ARGS[@]}" -eq 0 ]]; then
      REPORT_PATHS=()
      for candidate in \
        "$PROJECT_ROOT/target/surefire-reports" \
        "$PROJECT_ROOT/target/failsafe-reports" \
        "$PROJECT_ROOT/build/test-results" \
        "$PROJECT_ROOT/test-results" \
        "$PROJECT_ROOT/reports/junit"; do
        [[ -d "$candidate" ]] && REPORT_PATHS+=("$candidate")
      done
    fi

    if [[ "${#REPORT_PATHS[@]}" -eq 0 ]]; then
      error "未找到 JUnit 报告目录；请先运行测试（OPENSPEC_CHANGE_ID=<id> run-tests.sh），或显式传入报告路径"
    else
      evidence_out="$(python3 - "$CASES" "${REPORT_PATHS[@]}" <<'PY'
import os
import re
import sys
import xml.etree.ElementTree as ET

cases_path = sys.argv[1]
report_paths = sys.argv[2:]

def iter_xml(paths):
    for p in paths:
        if os.path.isfile(p) and p.endswith(".xml"):
            yield p
        elif os.path.isdir(p):
            for base, _, names in os.walk(p):
                for n in names:
                    if n.endswith(".xml"):
                        yield os.path.join(base, n)

TC_RE = re.compile(r"TC[-_]?0*(\d+)", re.IGNORECASE)

seen = set()        # 报告中出现的 TC 编号
failures = []       # 失败的测试名
parsed = 0
for f in iter_xml(report_paths):
    try:
        root = ET.parse(f).getroot()
    except ET.ParseError:
        continue
    found = False
    for tc in root.iter("testcase"):
        found = True
        name = (tc.get("name") or "") + " " + (tc.get("classname") or "")
        failed = any(c.tag in ("failure", "error") for c in tc)
        if failed:
            failures.append(tc.get("name") or "?")
        for m in TC_RE.finditer(name):
            if not failed:
                seen.add(int(m.group(1)))
    if found:
        parsed += 1

# 用例表中的非手动用例必须在报告中出现且通过
missing = []
for line in open(cases_path, encoding="utf-8"):
    line = line.strip()
    if not line.startswith("|"):
        continue
    cells = [c.strip() for c in line.strip("|").split("|")]
    if not cells:
        continue
    m = re.match(r"TC[-_]?0*(\d+)$", cells[0], re.IGNORECASE)
    if not m:
        continue
    if "手动" in cells:
        continue
    if int(m.group(1)) not in seen:
        missing.append(cells[0])

print(f"EVIDENCE_REPORTS={parsed} EVIDENCE_FAILURES={len(failures)} EVIDENCE_MISSING={len(missing)}")
for f in failures:
    print(f"FAILED_TEST: {f}")
for c in missing:
    print(f"MISSING_CASE: {c}")
PY
)"
      printf '%s\n' "$evidence_out"
      if grep -q 'EVIDENCE_REPORTS=0' <<<"$evidence_out"; then
        error "报告目录中没有可解析的 JUnit XML"
      fi
      if grep -q 'FAILED_TEST:' <<<"$evidence_out"; then
        error "存在失败的测试；修复后重跑，报告即证据"
      fi
      if grep -q 'MISSING_CASE:' <<<"$evidence_out"; then
        error "以下非手动用例在测试报告中没有对应通过记录（测试名须含 TC-ID）"
      fi
    fi
  fi
fi

if [[ "$fail" -eq 1 ]]; then
  echo "Test cases check failed."
  exit 2
fi

echo "Test cases check passed."
