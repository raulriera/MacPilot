#!/bin/sh
# Uninstalls MacPilot agent schedules from launchd.
#
# Unloads and removes selected com.macpilot.* plists from ~/Library/LaunchAgents/.
#
# Usage:
#   ./uninstall.sh          # Interactive — choose which agents to remove
#   ./uninstall.sh --all    # Remove all agents without prompting

set -e

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

# --- Selection ---
# When run without --all, displays a numbered list of installed agents
# and lets the user pick which ones to remove. Enter space-separated
# numbers, 'a' for all, or 'q' to quit.

select_all=false
if [ "${1:-}" = "--all" ]; then
  select_all=true
fi

# Check if a number is in the user's selection
is_selected() {
  if "$select_all"; then return 0; fi
  for _s in $selection; do
    [ "$_s" = "$1" ] && return 0
  done
  return 1
}

if ! "$select_all"; then
  # Display installed agents
  total=0
  for plist in "$LAUNCH_AGENTS"/com.macpilot.*.plist; do
    [ -f "$plist" ] || continue
    total=$((total + 1))
    agent="$(basename "$plist" .plist | sed 's/^com\.macpilot\.//')"
    printf "  %d) %s\n" "$total" "$agent"
  done

  if [ "$total" -eq 0 ]; then
    echo "No MacPilot agents found."
    exit 0
  fi

  printf "\nSelect agents to remove (space-separated numbers, 'a' for all, 'q' to quit): "
  read -r selection

  if [ "$selection" = "q" ]; then
    echo "Cancelled."
    exit 0
  fi

  # Normalize commas to spaces so "1,2,3" works the same as "1 2 3"
  selection="$(echo "$selection" | tr ',' ' ')"

  if [ "$selection" = "a" ]; then
    select_all=true
  fi
fi

# --- Remove selected plists ---

count=0
i=0

for plist in "$LAUNCH_AGENTS"/com.macpilot.*.plist; do
  [ -f "$plist" ] || continue
  i=$((i + 1))

  is_selected "$i" || continue

  label="$(basename "$plist" .plist)"

  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm "$plist"

  echo "Removed: $(basename "$plist")"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "No agents removed."
else
  echo "Done. $count agent(s) removed."
fi
