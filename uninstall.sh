#!/bin/sh
# Uninstalls MacPilot agent schedules from launchd.
#
# Unloads and removes every com.macpilot.* plist from ~/Library/LaunchAgents/.

set -e

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

count=0

for plist in "$LAUNCH_AGENTS"/com.macpilot.*.plist; do
  [ -f "$plist" ] || continue

  label="$(basename "$plist" .plist)"

  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm "$plist"

  echo "Removed: $(basename "$plist")"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "No MacPilot agents found."
else
  echo "Done. $count agent(s) removed."
fi
