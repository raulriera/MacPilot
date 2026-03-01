#!/bin/sh
# Installs MacPilot agent schedules into launchd.
#
# For each selected .plist in plists/, substitutes __MACPILOT_DIR__ with the
# actual project path, writes to ~/Library/LaunchAgents/, and loads it.
#
# Usage:
#   ./install.sh          # Interactive — choose which agents to install
#   ./install.sh --all    # Install all agents without prompting

set -e

MACPILOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

mkdir -p "$LAUNCH_AGENTS"
mkdir -p "$MACPILOT_DIR/logs"
mkdir -p "$MACPILOT_DIR/reports"
mkdir -p "$MACPILOT_DIR/tmp"

# Restrict permissions on dirs that may contain sensitive output
chmod 700 "$MACPILOT_DIR/logs" "$MACPILOT_DIR/reports" "$MACPILOT_DIR/tmp"

# Enforce restrictive permissions on .env (contains API keys)
if [ -f "$MACPILOT_DIR/config/.env" ]; then
  chmod 600 "$MACPILOT_DIR/config/.env"
fi

# Make agent and library scripts executable
chmod +x "$MACPILOT_DIR"/agents/*.sh
chmod +x "$MACPILOT_DIR"/lib/rotate-logs.sh 2>/dev/null || true

# --- Selection ---
# When run without --all, displays a numbered list of available agents
# and lets the user pick which ones to install. Enter space-separated
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
  # Display available agents
  total=0
  for plist in "$MACPILOT_DIR"/plists/*.plist; do
    [ -f "$plist" ] || continue
    total=$((total + 1))
    agent="$(basename "$plist" .plist | sed 's/^com\.macpilot\.//')"
    printf "  %d) %s\n" "$total" "$agent"
  done

  if [ "$total" -eq 0 ]; then
    echo "No plists found in plists/. Add one and re-run."
    exit 0
  fi

  printf "\nSelect agents to install (space-separated numbers, 'a' for all, 'q' to quit): "
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

# --- Install selected plists ---

count=0
i=0

for plist in "$MACPILOT_DIR"/plists/*.plist; do
  [ -f "$plist" ] || continue
  i=$((i + 1))

  is_selected "$i" || continue

  name="$(basename "$plist")"
  dest="$LAUNCH_AGENTS/$name"
  label="$(basename "$name" .plist)"

  # Unload if already loaded
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true

  # Substitute placeholder paths and write to LaunchAgents
  sed -e "s|__MACPILOT_DIR__|$MACPILOT_DIR|g" -e "s|__HOME__|$HOME|g" "$plist" > "$dest"

  # Load
  launchctl bootstrap "gui/$(id -u)" "$dest"

  echo "Installed: $name"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "No agents installed."
else
  echo "Done. $count agent(s) installed."
fi
