#!/usr/bin/env bash
set -euo pipefail

# SQL 安全检查：语句级分析，而非逐行 grep。
# 流程：剥离注释和字符串字面量 -> 按分号重组完整语句 -> 逐句判定，报错带语句起始行号。
# 判定项：SELECT *、无 WHERE 的 DELETE/UPDATE、DROP、TRUNCATE、无 ON/USING 的 JOIN。

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: $0 <sql-file>"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for sql-safety-check" >&2
  exit 1
fi

python3 - "$FILE" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as f:
    text = f.read()

# 剥离注释和字符串字面量，保留换行以维持行号。
def strip_noise(src):
    out = []
    i, n = 0, len(src)
    while i < n:
        ch = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if ch == "-" and nxt == "-":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if ch == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if ch == "/" and nxt == "*":
            i += 2
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                if src[i] == "\n":
                    out.append("\n")
                i += 1
            i += 2
            continue
        if ch in ("'", '"', "`"):
            quote = ch
            i += 1
            out.append(quote + quote)  # 用空字面量占位
            while i < n:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == quote:
                    if i + 1 < n and src[i + 1] == quote:  # '' 转义
                        i += 2
                        continue
                    i += 1
                    break
                if src[i] == "\n":
                    out.append("\n")
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)

clean = strip_noise(text)

# 按分号切分为 (起始行号, 语句文本)
statements = []
line = 1
start_line = None
buf = []
for ch in clean:
    if ch == "\n":
        line += 1
    if ch == ";":
        if buf and start_line is not None:
            statements.append((start_line, "".join(buf)))
        buf = []
        start_line = None
        continue
    if start_line is None and not ch.isspace():
        start_line = line
    if start_line is not None:
        buf.append(ch)
if buf and start_line is not None:
    statements.append((start_line, "".join(buf)))

failures = []

def fail(ln, msg):
    failures.append((ln, msg))

for ln, raw in statements:
    stmt = re.sub(r"\s+", " ", raw).strip().upper()
    if not stmt:
        continue

    if re.search(r"\bSELECT\s+(?:\w+\s*\.\s*)?\*", stmt):
        fail(ln, "SELECT * is forbidden")

    if re.match(r"DELETE\b", stmt) and not re.search(r"\bWHERE\b", stmt):
        fail(ln, "DELETE without WHERE is forbidden")

    if re.match(r"UPDATE\b", stmt) and re.search(r"\bSET\b", stmt) and not re.search(r"\bWHERE\b", stmt):
        fail(ln, "UPDATE without WHERE is forbidden")

    if re.search(r"\bDROP\s+(TABLE|COLUMN|DATABASE|INDEX)\b", stmt):
        fail(ln, "DROP requires explicit approval")

    if re.search(r"\bTRUNCATE\b", stmt):
        fail(ln, "TRUNCATE requires explicit approval")

    joins = re.findall(r"\b(?:INNER\s+|LEFT\s+(?:OUTER\s+)?|RIGHT\s+(?:OUTER\s+)?|FULL\s+(?:OUTER\s+)?|CROSS\s+)?JOIN\b", stmt)
    if joins:
        anchors = re.findall(r"\bON\b|\bUSING\b", stmt)
        cross = re.findall(r"\bCROSS\s+JOIN\b", stmt)
        if len(anchors) < len(joins) - len(cross):
            fail(ln, "JOIN without ON/USING is forbidden")

for ln, msg in failures:
    print(f"[FAIL] line {ln}: {msg}")

if failures:
    print("SQL safety check failed.")
    sys.exit(2)

print("SQL safety check passed.")
PY
