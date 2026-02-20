#!/bin/sh
# macpilot.sh — shared library for MacPilot agents
# Source this at the top of every agent script:
#   . "$(dirname "$0")/../lib/macpilot.sh"

set -e

MACPILOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MACPILOT_LOGS="$MACPILOT_DIR/logs"
MACPILOT_REPORTS="$MACPILOT_DIR/reports"
MACPILOT_ENV="$MACPILOT_DIR/config/.env"

# Agent name derived from the calling script filename
AGENT_NAME="$(basename "$0" .sh)"

# --- Find claude CLI ---

find_claude() {
  for path in \
    "$HOME/.local/bin/claude" \
    "/usr/local/bin/claude" \
    "/opt/homebrew/bin/claude"; do
    if [ -x "$path" ]; then
      echo "$path"
      return
    fi
  done

  # Fall back to PATH
  command -v claude 2>/dev/null && return

  echo "ERROR: claude CLI not found" >&2
  exit 1
}

CLAUDE_BIN="$(find_claude)"

# --- Load .env ---

if [ -f "$MACPILOT_ENV" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and blank lines
    case "$line" in
      \#*|"") continue ;;
    esac
    # Strip surrounding quotes from value
    key="${line%%=*}"
    value="${line#*=}"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    export "$key=$value"
  done < "$MACPILOT_ENV"
fi

# --- Notify ---

notify() {
  title="$1"
  message="$2"
  osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
}

# --- Run agent ---

# Usage: run_agent "prompt" [extra claude flags...]
#
# Calls claude CLI with sensible defaults, parses the JSON response,
# logs the result, and sends a macOS notification.
#
# Override defaults by passing extra flags:
#   run_agent "do something" --max-turns 5 --model opus

run_agent() {
  prompt="$1"
  shift

  # Defaults (can be overridden via extra args)
  model="sonnet"
  max_turns="10"
  timeout="300"

  # Parse extra args to extract overrides
  extra_args=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --model)     model="$2"; shift 2 ;;
      --max-turns) max_turns="$2"; shift 2 ;;
      --timeout)   timeout="$2"; shift 2 ;;
      *)           extra_args="$extra_args $1"; shift ;;
    esac
  done

  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  log_file="$MACPILOT_LOGS/$AGENT_NAME.log"

  echo "[$timestamp] Running agent: $AGENT_NAME" >> "$log_file"

  system_prompt="You are MacPilot, an autonomous agent running a scheduled task on macOS. Execute the task completely without asking for confirmation. Be concise in your final response."

  # Build and run the command with a timeout to prevent hangs
  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' EXIT

  "$CLAUDE_BIN" \
    -p "$prompt" \
    --output-format json \
    --model "$model" \
    --max-turns "$max_turns" \
    --no-session-persistence \
    --append-system-prompt "$system_prompt" \
    $extra_args > "$tmpfile" 2>> "$log_file" &
  pid=$!

  # Kill the process if it exceeds the timeout
  ( sleep "$timeout" && kill "$pid" 2>/dev/null ) &
  watcher=$!

  wait "$pid" 2>/dev/null && exit_code=0 || exit_code=$?

  # Clean up the watcher
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true

  result="$(cat "$tmpfile")"
  rm -f "$tmpfile"
  trap - EXIT

  if [ "$exit_code" -ne 0 ]; then
    echo "[$timestamp] FAILED (exit $exit_code)" >> "$log_file"
    echo "Agent $AGENT_NAME failed (exit $exit_code). See $log_file"
    notify "MacPilot: $AGENT_NAME" "Agent failed. Check logs."
    exit 1
  fi

  # Parse the text response from JSON output
  text="$(echo "$result" | jq -r '
    if type == "array" then
      map(select(.type == "result")) | last | .result // empty
    elif .result then
      .result
    else
      empty
    end
  ' 2>/dev/null)"

  # Handle missing result (e.g. error_max_turns)
  if [ -z "$text" ]; then
    subtype="$(echo "$result" | jq -r '.subtype // empty' 2>/dev/null)"
    if [ -n "$subtype" ]; then
      text="Agent stopped: $subtype"
    else
      text="$result"
    fi
  fi

  # Log
  echo "[$timestamp] OK" >> "$log_file"
  echo "$text" >> "$log_file"
  echo "---" >> "$log_file"

  # Notify
  # Truncate to 200 chars for notification
  short="$(echo "$text" | head -c 200)"
  notify "MacPilot: $AGENT_NAME" "$short"

  # Print to stdout (captured by launchd into the .log file)
  echo "$text"
}
