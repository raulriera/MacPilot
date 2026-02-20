#!/bin/sh
# rotate-logs.sh — delete logs and reports older than N days.
#
# Usage:
#   lib/rotate-logs.sh [days]
#
# Defaults to 30 days. Override with MACPILOT_LOG_RETENTION_DAYS or pass as $1.

set -e

MACPILOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RETENTION_DAYS="${1:-${MACPILOT_LOG_RETENTION_DAYS:-30}}"

deleted=0

for dir in "$MACPILOT_DIR/logs" "$MACPILOT_DIR/reports"; do
  [ -d "$dir" ] || continue
  # Find and delete files older than retention period
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    rm -f "$file"
    deleted=$((deleted + 1))
  done <<EOF
$(find "$dir" -type f -mtime +"$RETENTION_DAYS" 2>/dev/null)
EOF
done

echo "Log rotation: deleted $deleted file(s) older than $RETENTION_DAYS days."
