#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$ROOT/openspec/config.yaml"
TARGET="${1:-}"

if [[ -z "$TARGET" || ! -e "$TARGET" ]]; then
  echo "Usage: $0 <openspec-change-or-file>" >&2
  exit 1
fi

fail=0
tmp_file="/tmp/openspec-language-check.$$"
STRICT_CHINESE="${OPENSPEC_STRICT_CHINESE:-1}"

to_regex_pattern() {
  awk '
    NF {
      line=$0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      gsub(/[][(){}.^$*+?|\\]/, "\\\\&", line)
      gsub(/[[:space:]]+/, "[[:space:]]+", line)
      print line
    }
  ' | paste -sd '|' -
}

yaml_glossary_keys() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  awk '
    /^glossary:/ { in_glossary=1; next }
    in_glossary && /^[^[:space:]]/ { exit }
    in_glossary && /^[[:space:]]+[A-Za-z][A-Za-z -]*:/ {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/:.*/, "", line)
      print line
    }
  ' "$CONFIG_FILE"
}

yaml_rule_list() {
  local section="$1"
  local key="$2"
  [[ -f "$CONFIG_FILE" ]] || return 0

  awk -v section="$section" -v key="$key" '
    /^rules:/ { in_rules=1; next }
    in_rules && /^  [a-z_]+:/ {
      current=$1
      sub(/:$/, "", current)
      in_section=(current == section)
      in_list=0
      next
    }
    in_section && $0 ~ "^[[:space:]]{4}" key ":" {
      in_list=1
      next
    }
    in_section && in_list && /^[[:space:]]{6}-[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      print line
      next
    }
    in_section && in_list && /^[[:space:]]{4}[a-z_]+:/ { exit }
  ' "$CONFIG_FILE"
}

GLOSSARY_HEADING_PATTERN="$(yaml_glossary_keys | to_regex_pattern)"
TASK_STATUS_PATTERN="$(yaml_rule_list tasks forbidden_terms | to_regex_pattern)"
REQUIREMENT_KEYWORD_PATTERN="$(yaml_rule_list spec forbidden | awk '/^[A-Z][A-Z ]+$/' | to_regex_pattern)"
API_FIELD_LABEL_PATTERN="$(yaml_glossary_keys | awk '$0 == "Method" || $0 == "Path" || $0 == "Auth"' | to_regex_pattern)"

if [[ -z "$GLOSSARY_HEADING_PATTERN" ]]; then
  GLOSSARY_HEADING_PATTERN='Overview|Summary|Goals|Non-goals|Requirements|Requirement|Scenario|Features|Tasks|Design|Architecture|Database|Pending|Todo|Done|Completed|In[[:space:]]+Progress|Draft|Review|Deploy|Testing|Success|Failed|Error|Why|What|Impact|Scope|Endpoint|Request|Response|Errors|Pagination|Security|Method|Path|Auth'
fi

if [[ -z "$TASK_STATUS_PATTERN" ]]; then
  TASK_STATUS_PATTERN='Todo|Pending|Done|Completed|In[[:space:]]+Progress'
fi

if [[ -z "$REQUIREMENT_KEYWORD_PATTERN" ]]; then
  REQUIREMENT_KEYWORD_PATTERN='SHALL|MUST|SHOULD|GIVEN|WHEN|THEN|AND[[:space:]]+SHALL'
fi

if [[ -z "$API_FIELD_LABEL_PATTERN" ]]; then
  API_FIELD_LABEL_PATTERN='Method|Path|Auth'
fi

error() {
  printf '[FAIL] %s\n' "$*"
  fail=1
}

check_english_business_sentences() {
  local file="$1"

  awk '
    BEGIN { in_code = 0 }

    /^[[:space:]]*(```|~~~)/ {
      in_code = !in_code
      next
    }

    in_code { next }

    {
      original = $0
      line = $0

      if (line ~ /^[[:space:]]*$/) next
      if (line ~ /^[[:space:]]*\|?[[:space:]-]+\|[[:space:]-|]*$/) next
      if (line ~ /^[[:space:]]*<!--/) next

      gsub(/`[^`]*`/, "", line)
      gsub(/https?:\/\/[^[:space:]]+/, "", line)
      gsub(/\/[A-Za-z0-9_\/{}:.?=&%-]+/, "", line)
      gsub(/[A-Za-z0-9_.+-]+@[A-Za-z0-9_.-]+/, "", line)

      lower = " " tolower(line) " "
      count = split(line, words, /[^A-Za-z]+/)
      english_words = 0

      for (i = 1; i <= count; i++) {
        token = tolower(words[i])
        if (token ~ /^(api|aop|auth|base|bean|boot|controller|crud|db|docker|dto|entity|enum|errorcode|flyway|h2|http|java|javascript|json|jwt|knife4j|log|lombok|long|mapper|maven|mvc|mysql|mybatis|number|openapi|pagehelper|pom|query|rbac|redis|request|response|service|spring|sql|string|swagger|token|url|vo|web|xml)$/) {
          continue
        }
        if (length(words[i]) >= 2) {
          english_words++
        }
      }

      natural_sentence = lower ~ / (the|this|that|these|those|feature|function|system|user|users|supplier|suppliers|admin|allows|allow|should|must|will|can|cannot|needs|need|submit|create|update|delete|return|returns|support|supports|validate|validates|display|displays|manage|manages|configure|configures|provide|provides|handle|handles|when|then|given|with|without|from|into|before|after) /

      if ((english_words >= 5 && natural_sentence) || english_words >= 10) {
        print FILENAME ":" FNR ": possible English business sentence: " original
      }
    }
  ' "$file" >"$tmp_file" 2>/dev/null || true

  if [[ -s "$tmp_file" ]]; then
    while IFS= read -r hit; do
      error "$hit"
    done < "$tmp_file"
  fi

  rm -f "$tmp_file"
}

check_file() {
  local file="$1"
  local line_no heading hit

  while IFS=: read -r line_no heading; do
    if [[ "$heading" =~ (^|[[:space:]:：])($GLOSSARY_HEADING_PATTERN)([[:space:]:：]|$) ]]; then
      error "${file}:${line_no}: heading should use Chinese: ${heading}"
    fi
  done < <(grep -En '^#{1,6}[[:space:]]+' "$file" || true)

  if grep -En "\\b(${TASK_STATUS_PATTERN})\\b" "$file" >"$tmp_file" 2>/dev/null; then
    while IFS= read -r hit; do
      error "${file}: forbidden task status: ${hit}"
    done < "$tmp_file"
  fi

  if grep -En "\\b(${REQUIREMENT_KEYWORD_PATTERN})\\b" "$file" >"$tmp_file" 2>/dev/null; then
    while IFS= read -r hit; do
      error "${file}: forbidden English requirement keyword: ${hit}"
    done < "$tmp_file"
  fi

  if grep -En "^[[:space:]]*-[[:space:]]*(${API_FIELD_LABEL_PATTERN}):" "$file" >"$tmp_file" 2>/dev/null; then
    while IFS= read -r hit; do
      error "${file}: API field label should use Chinese: ${hit}"
    done < "$tmp_file"
  fi

  if [[ "$STRICT_CHINESE" != "0" ]]; then
    check_english_business_sentences "$file"
  fi

  rm -f "$tmp_file"
}

if [[ -d "$TARGET" ]]; then
  while IFS= read -r file; do
    check_file "$file"
  done < <(find "$TARGET" -type f -name '*.md' | sort)
else
  check_file "$TARGET"
fi

if [[ "$fail" -eq 1 ]]; then
  echo "OpenSpec language check failed."
  rm -f "$tmp_file"
  exit 2
fi

echo "OpenSpec language check passed."
