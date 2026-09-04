#!/usr/bin/env bash
set -euo pipefail

# 用例状态自动回填：解析 JUnit XML 测试报告，按用例ID（TC-NN）匹配测试名，
# 把 test-cases.md 状态列自动改写为 通过/失败。
#
# 匹配约定：测试方法名、describe 名或 classname 中包含用例ID，例如
#   test_TC01_分页查询 / TC-02_非法参数 / DemoTest#tc03ShouldFail
# 大小写不敏感，TC01 / TC-01 / TC_01 均可。
#
# 规则：
# - 验证方式为“手动”的用例不回填，始终由人工确认。
# - 报告中匹配不到的用例保持原状态（如“已设计”），由 --require-filled 门禁兜底。
# - 同一用例匹配到多条测试结果时，任一失败即记为失败。
#
# 用法：
#   test-cases-sync.sh <change-dir> [junit-xml-或目录 ...]
#   不指定报告路径时，自动在项目根搜索常见位置：
#     target/surefire-reports、target/failsafe-reports、build/test-results、test-results、reports/junit

CHANGE_DIR="${1:-}"
shift || true

if [[ -z "$CHANGE_DIR" || ! -d "$CHANGE_DIR" ]]; then
  echo "Usage: $0 <openspec/changes/change-id> [junit-xml-or-dir ...]" >&2
  exit 1
fi

CASES="$CHANGE_DIR/test-cases.md"
if [[ ! -f "$CASES" ]]; then
  echo "缺少 $CASES" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for test-cases-sync" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT"
if [[ "$(basename "$ROOT")" == "control" && "$(basename "$(dirname "$ROOT")")" == ".ai-control" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/../.." && pwd)"
elif [[ "$(basename "$ROOT")" == "control" && -f "$ROOT/../AGENTS.md" ]]; then
  PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
fi

REPORT_PATHS=("$@")
if [[ "${#REPORT_PATHS[@]}" -eq 0 ]]; then
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
  echo "SYNC_SKIPPED: 未找到 JUnit 报告目录；可显式传入报告路径。"
  exit 0
fi

python3 - "$CASES" "${REPORT_PATHS[@]}" <<'PY'
import os
import re
import sys
import xml.etree.ElementTree as ET

cases_path = sys.argv[1]
report_paths = sys.argv[2:]

def iter_xml_files(paths):
    for p in paths:
        if os.path.isfile(p) and p.endswith(".xml"):
            yield p
        elif os.path.isdir(p):
            for base, _, names in os.walk(p):
                for name in names:
                    if name.endswith(".xml"):
                        yield os.path.join(base, name)

TC_RE = re.compile(r"TC[-_]?0*(\d+)", re.IGNORECASE)

# tc_id(规范化数字) -> True=有失败
results = {}
parsed_files = 0
for xml_file in iter_xml_files(report_paths):
    try:
        tree = ET.parse(xml_file)
    except ET.ParseError:
        continue
    root = tree.getroot()
    testcases = root.iter("testcase")
    found_any = False
    for tc in testcases:
        found_any = True
        name = (tc.get("name") or "") + " " + (tc.get("classname") or "")
        failed = any(child.tag in ("failure", "error") for child in tc)
        skipped = any(child.tag == "skipped" for child in tc)
        if skipped:
            continue
        for m in TC_RE.finditer(name):
            key = int(m.group(1))
            results[key] = results.get(key, False) or failed
    if found_any:
        parsed_files += 1

with open(cases_path, encoding="utf-8") as f:
    lines = f.readlines()

updated = failed_count = manual = unmatched = 0
out = []
for line in lines:
    stripped = line.strip()
    if stripped.startswith("|"):
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        m = re.match(r"TC[-_]?0*(\d+)$", cells[0], re.IGNORECASE) if cells else None
        if m and len(cells) >= 2:
            key = int(m.group(1))
            if "手动" in cells:
                manual += 1
                out.append(line)
                continue
            if key in results:
                new_status = "失败" if results[key] else "通过"
                if results[key]:
                    failed_count += 1
                cells[-1] = new_status
                indent = line[: len(line) - len(line.lstrip())]
                out.append(indent + "| " + " | ".join(cells) + " |\n")
                updated += 1
                continue
            unmatched += 1
    out.append(line)

with open(cases_path, "w", encoding="utf-8") as f:
    f.writelines(out)

print(f"SYNC_REPORTS_PARSED={parsed_files}")
print(f"SYNC_UPDATED={updated} SYNC_FAILED={failed_count} SYNC_MANUAL_KEPT={manual} SYNC_UNMATCHED={unmatched}")
if failed_count:
    print("注意：存在失败用例，必须修复或在残余风险中明确记录。")
PY
