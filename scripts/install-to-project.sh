#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN=0
BACKUP=0
FORCE=0
MERGE=0
PROFILE="default"
TARGET=""
ONLY_ITEMS=()
EXCLUDE_ITEMS=()

installed=0
skipped=0
backed_up=0
conflicts=0

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/install-to-project.sh [options] /path/to/project

Options:
  --dry-run             Print planned actions without writing files.
  --backup              Back up conflicting target paths before replacing.
  --force               Replace existing target files or directories.
  --merge               Merge directories; file conflicts still require --force or --backup.
  --only <path>         Install only one item. Can be repeated.
  --profile <name|path> Use profiles/<name>/profile.toml or a profile file path.
  -h, --help            Show this help.
USAGE
}

log() {
  printf '%s\n' "$*"
}

fail() {
  log "[FAIL] $*" >&2
  exit 1
}

validate_item() {
  local item="$1"
  [[ -n "$item" ]] || fail "Empty install item"
  [[ "$item" != /* ]] || fail "Install item must be relative: $item"
  [[ "$item" != *".."* ]] || fail "Install item must not contain '..': $item"
  [[ -e "$ROOT/$item" ]] || fail "Install item does not exist in source: $item"
}

profile_file() {
  local profile="$1"
  if [[ -f "$profile" ]]; then
    printf '%s\n' "$profile"
  elif [[ -f "$ROOT/profiles/$profile/profile.toml" ]]; then
    printf '%s\n' "$ROOT/profiles/$profile/profile.toml"
  else
    fail "Profile not found: $profile"
  fi
}

read_profile_items() {
  local file="$1"
  local key="${2:-items}"
  awk '
    BEGIN { in_list=0; key=ARGV[2]; ARGV[2]="" }
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" { in_list=1 }
    in_list {
      line=$0
      while (match(line, /"([^"]+)"/)) {
        print substr(line, RSTART + 1, RLENGTH - 2)
        line=substr(line, RSTART + RLENGTH)
      }
      if ($0 ~ /\]/) { in_list=0 }
    }
  ' "$file" "$key"
}

is_excluded() {
  local item="$1"
  local exclude
  [[ "${#EXCLUDE_ITEMS[@]}" -eq 0 ]] && return 1
  for exclude in "${EXCLUDE_ITEMS[@]}"; do
    if [[ "$item" == "$exclude" || "$item" == "$exclude/"* ]]; then
      return 0
    fi
  done
  return 1
}

has_nested_exclusion() {
  local item="$1"
  local exclude
  [[ "${#EXCLUDE_ITEMS[@]}" -eq 0 ]] && return 1
  for exclude in "${EXCLUDE_ITEMS[@]}"; do
    if [[ "$exclude" == "$item/"* ]]; then
      return 0
    fi
  done
  return 1
}

copy_path() {
  local item="$1"
  local src="$ROOT/$item"
  local dst="$TARGET/$item"
  local backup_root="$TARGET/.agent/install-backup/$RUN_ID"

  validate_item "$item"

  if is_excluded "$item"; then
    log "[SKIP] $item"
    skipped=$((skipped + 1))
    return
  fi

  if [[ -d "$src" ]] && has_nested_exclusion "$item"; then
    log "[EXPAND] $item"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      mkdir -p "$dst"
    fi
    while IFS= read -r child; do
      local child_item="${item}/${child#./}"
      copy_path "$child_item"
    done < <(cd "$src" && find . -mindepth 1 -maxdepth 1 -print)
    skipped=$((skipped + 1))
    return
  fi

  if [[ -e "$dst" ]]; then
    if [[ -d "$src" && -d "$dst" && "$MERGE" -eq 1 ]]; then
      log "[MERGE] $item"
      if [[ "$DRY_RUN" -eq 0 ]]; then
        mkdir -p "$dst"
      fi
      while IFS= read -r child; do
        local child_item="${item}/${child#./}"
        copy_path "$child_item"
      done < <(cd "$src" && find . -mindepth 1 -maxdepth 1 -print)
      skipped=$((skipped + 1))
      return
    fi

    if [[ "$BACKUP" -eq 1 ]]; then
      log "[BACKUP] $item -> .agent/install-backup/$RUN_ID/$item"
      if [[ "$DRY_RUN" -eq 0 ]]; then
        mkdir -p "$(dirname "$backup_root/$item")"
        cp -R "$dst" "$backup_root/$item"
      fi
      backed_up=$((backed_up + 1))
    elif [[ "$FORCE" -ne 1 ]]; then
      log "[CONFLICT] $item"
      conflicts=$((conflicts + 1))
      return
    fi

    if [[ "$FORCE" -eq 1 || "$BACKUP" -eq 1 ]]; then
      log "[REPLACE] $item"
      if [[ "$DRY_RUN" -eq 0 ]]; then
        rm -rf "$dst"
      fi
    fi
  else
    log "[INSTALL] $item"
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
  fi
  installed=$((installed + 1))
}

detect_conflict() {
  local item="$1"
  local src="$ROOT/$item"
  local dst="$TARGET/$item"

  validate_item "$item"

  if is_excluded "$item"; then
    return
  fi

  if [[ -e "$dst" ]]; then
    if [[ -d "$src" && -d "$dst" && "$MERGE" -eq 1 ]]; then
      while IFS= read -r child; do
        local child_item="${item}/${child#./}"
        detect_conflict "$child_item"
      done < <(cd "$src" && find . -mindepth 1 -maxdepth 1 -print)
      return
    fi

    log "[CONFLICT] $item"
    conflicts=$((conflicts + 1))
  fi
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --backup)
      BACKUP=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --merge)
      MERGE=1
      shift
      ;;
    --only)
      [[ "${2:-}" ]] || fail "--only requires a path"
      ONLY_ITEMS+=("$2")
      shift 2
      ;;
    --profile)
      [[ "${2:-}" ]] || fail "--profile requires a name or path"
      PROFILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      fail "Unknown option: $1"
      ;;
    *)
      [[ -z "$TARGET" ]] || fail "Only one target directory is allowed"
      TARGET="$1"
      shift
      ;;
  esac
done

[[ -n "$TARGET" ]] || { usage; exit 1; }
if [[ ! -d "$TARGET" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] Target directory does not exist yet: $TARGET"
  else
    fail "Target directory does not exist: $TARGET"
  fi
fi

RUN_ID="$(date +%Y%m%d%H%M%S)"

ITEMS=()
if [[ "${#ONLY_ITEMS[@]}" -gt 0 ]]; then
  ITEMS=("${ONLY_ITEMS[@]}")
else
  PROFILE_FILE="$(profile_file "$PROFILE")"
  while IFS= read -r item; do
    [[ -n "$item" ]] && ITEMS+=("$item")
  done < <(read_profile_items "$PROFILE_FILE" "items")
  while IFS= read -r item; do
    [[ -n "$item" ]] && EXCLUDE_ITEMS+=("$item")
  done < <(read_profile_items "$PROFILE_FILE" "exclude_items")
  [[ "${#ITEMS[@]}" -gt 0 ]] || fail "Profile has no items: $PROFILE_FILE"
fi

log "Install target: $TARGET"
log "Profile: $PROFILE"
[[ "$DRY_RUN" -eq 1 ]] && log "Mode: dry-run"

if [[ "$DRY_RUN" -eq 0 && "$FORCE" -eq 0 && "$BACKUP" -eq 0 ]]; then
  for item in "${ITEMS[@]}"; do
    detect_conflict "$item"
  done

  if [[ "$conflicts" -gt 0 ]]; then
    log ""
    log "Summary:"
    log "  installed: 0"
    log "  skipped: 0"
    log "  backed up: 0"
    log "  conflicts: $conflicts"
    log "Install failed before copying because conflicts were found. Re-run with --backup, --force, or --merge after review."
    exit 2
  fi
fi

for item in "${ITEMS[@]}"; do
  copy_path "$item"
done

log ""
log "Summary:"
log "  installed: $installed"
log "  skipped: $skipped"
log "  backed up: $backed_up"
log "  conflicts: $conflicts"

if [[ "$conflicts" -gt 0 ]]; then
  log "Install failed because conflicts were found. Re-run with --backup, --force, or --merge after review."
  exit 2
fi

log "Install completed."
