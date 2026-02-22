#!/bin/sh
# Installs MacPilot agent schedules into launchd.
#
# For each .plist in plists/, substitutes __MACPILOT_DIR__ with the
# actual project path, writes to ~/Library/LaunchAgents/, and loads it.

set -e

MACPILOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

mkdir -p "$LAUNCH_AGENTS"
mkdir -p "$MACPILOT_DIR/logs"
mkdir -p "$MACPILOT_DIR/reports"

# Restrict permissions on dirs that may contain sensitive output
chmod 700 "$MACPILOT_DIR/logs" "$MACPILOT_DIR/reports"

# Enforce restrictive permissions on .env (contains API keys)
if [ -f "$MACPILOT_DIR/config/.env" ]; then
  chmod 600 "$MACPILOT_DIR/config/.env"
fi

# Make agent and library scripts executable
chmod +x "$MACPILOT_DIR"/agents/*.sh
chmod +x "$MACPILOT_DIR"/lib/rotate-logs.sh 2>/dev/null || true

count=0

for plist in "$MACPILOT_DIR"/plists/*.plist; do
  [ -f "$plist" ] || continue

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
  echo "No plists found in plists/. Add one and re-run."
else
  echo "Done. $count agent(s) installed."
fi
