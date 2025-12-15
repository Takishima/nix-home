#!/usr/bin/env bash
# hm-sys - Manage system files staged by home-manager
# Variables @STAGING_DIR@, @JQ@, @DIFFUTILS@, @BAT@, @COREUTILS@ are substituted at build time

set -euo pipefail

STAGING_DIR="@STAGING_DIR@"
MANIFEST_FILE="$STAGING_DIR/.manifest"
CHECKSUM_FILE="$STAGING_DIR/.checksums"

JQ="@JQ@"
DIFFUTILS="@DIFFUTILS@"
BAT="@BAT@"
COREUTILS="@COREUTILS@"

show_help() {
  echo "hm-sys - Manage system files staged by home-manager"
  echo ""
  echo "Usage: hm-sys <command>"
  echo ""
  echo "Commands:"
  echo "  status    Show sync status of managed files"
  echo "  diff      Show differences between staged and system files"
  echo "  apply     Apply staged files to system (requires sudo)"
  echo "  help      Show this help message"
  echo ""
  echo "Environment variables:"
  echo "  HM_ETC_SKIP=1     Skip /etc checks during home-manager activation"
  echo "  HM_ETC_PROMPT=1   Auto-apply during activation (if promptMode enabled)"
}

check_manifest() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: No manifest file found at $MANIFEST_FILE"
    echo "Run 'home-manager switch' first to stage files."
    exit 1
  fi
}

cmd_status() {
  check_manifest
  echo "Managed system files status:"
  echo ""

  "$JQ" -c '.[]' "$MANIFEST_FILE" | while IFS= read -r entry; do
    etc_path=$(echo "$entry" | "$JQ" -r '.path')

    src="$STAGING_DIR/files/$etc_path"
    dst="/etc/$etc_path"

    if [ ! -f "$dst" ]; then
      echo "  [MISSING]  /etc/$etc_path"
    elif ! "$DIFFUTILS/bin/diff" -q "$dst" "$src" >/dev/null 2>&1; then
      echo "  [CHANGED]  /etc/$etc_path"
    else
      echo "  [OK]       /etc/$etc_path"
    fi
  done
}

cmd_diff() {
  check_manifest
  has_diff=0

  "$JQ" -c '.[]' "$MANIFEST_FILE" | while IFS= read -r entry; do
    etc_path=$(echo "$entry" | "$JQ" -r '.path')

    src="$STAGING_DIR/files/$etc_path"
    dst="/etc/$etc_path"

    if [ ! -f "$dst" ]; then
      echo "=== NEW FILE: /etc/$etc_path ==="
      "$BAT/bin/bat" --style=plain --paging=never "$src" 2>/dev/null || cat "$src"
      echo ""
      has_diff=1
    elif ! "$DIFFUTILS/bin/diff" -q "$dst" "$src" >/dev/null 2>&1; then
      echo "=== CHANGED: /etc/$etc_path ==="
      "$DIFFUTILS/bin/diff" --color=always -u "$dst" "$src" || true
      echo ""
      has_diff=1
    fi
  done

  if [ "$has_diff" = "0" ]; then
    echo "All system files are in sync."
  fi
}

cmd_apply() {
  check_manifest
  echo "Applying staged system files..."
  echo ""

  # Process each file in manifest
  "$JQ" -c '.[]' "$MANIFEST_FILE" | while IFS= read -r entry; do
    etc_path=$(echo "$entry" | "$JQ" -r '.path')
    mode=$(echo "$entry" | "$JQ" -r '.mode')

    src="$STAGING_DIR/files/$etc_path"
    dst="/etc/$etc_path"

    # Create backup if file exists
    if [ -f "$dst" ]; then
      backup="$dst.hm-backup"
      echo "  Backing up $dst -> $backup"
      sudo cp "$dst" "$backup"
    fi

    # Create parent directory if needed
    dst_dir=$(dirname "$dst")
    if [ ! -d "$dst_dir" ]; then
      echo "  Creating directory $dst_dir"
      sudo mkdir -p "$dst_dir"
    fi

    # Copy file
    echo "  Installing $dst (mode $mode)"
    sudo cp "$src" "$dst"
    sudo chmod "$mode" "$dst"
  done

  # Update checksums
  echo ""
  echo "Updating checksums..."
  rm -f "$CHECKSUM_FILE"
  "$JQ" -c '.[]' "$MANIFEST_FILE" | while IFS= read -r entry; do
    etc_path=$(echo "$entry" | "$JQ" -r '.path')
    hash=$("$COREUTILS/bin/sha256sum" "/etc/$etc_path" | cut -d' ' -f1)
    echo "$etc_path:$hash" >>"$CHECKSUM_FILE"
  done

  echo ""
  echo "Done! All system files are now in sync."
}

# Main command dispatch
case "${1:-help}" in
status)
  cmd_status
  ;;
diff)
  cmd_diff
  ;;
apply)
  cmd_apply
  ;;
help | --help | -h)
  show_help
  ;;
*)
  echo "Unknown command: $1"
  echo ""
  show_help
  exit 1
  ;;
esac
