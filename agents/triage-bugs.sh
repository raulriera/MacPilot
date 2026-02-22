#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

if [ -z "$PROJECT_DIR" ]; then
  echo "PROJECT_DIR not set" >&2
  notify "MacPilot: $AGENT_NAME" "PROJECT_DIR not set. Check .env or plist."
  exit 1
fi

if [ -z "$BUGSNAG_API_KEY" ]; then
  echo "BUGSNAG_API_KEY not set" >&2
  notify "MacPilot: $AGENT_NAME" "BUGSNAG_API_KEY not set. Check .env or plist."
  exit 1
fi

if [ -z "$BUGSNAG_PROJECT_ID" ]; then
  echo "BUGSNAG_PROJECT_ID not set" >&2
  notify "MacPilot: $AGENT_NAME" "BUGSNAG_PROJECT_ID not set. Check .env or plist."
  exit 1
fi

cd "$PROJECT_DIR" || exit 1
sync_repo || exit 1

# Fetch BugSnag data in shell (outside Claude) to avoid passing untrusted
# external data through a prompt that has Bash access.
bugsnag_file="$(mktemp)"
trap 'rm -f "$bugsnag_file"' EXIT INT TERM

# Get the top error
top_error="$(curl -sf -H "Authorization: token $BUGSNAG_API_KEY" \
  "https://api.bugsnag.com/projects/$BUGSNAG_PROJECT_ID/errors?sort=events&direction=desc&per_page=1" 2>/dev/null)"

if [ -z "$top_error" ]; then
  echo "Failed to fetch errors from BugSnag" >&2
  notify "MacPilot: $AGENT_NAME" "Failed to fetch BugSnag errors." "high"
  rm -f "$bugsnag_file"
  trap - EXIT INT TERM
  exit 1
fi

# Extract the error ID and fetch the latest event
error_id="$(printf '%s' "$top_error" | jq -r '.[0].id // empty' 2>/dev/null)"

if [ -n "$error_id" ]; then
  latest_event="$(curl -sf -H "Authorization: token $BUGSNAG_API_KEY" \
    "https://api.bugsnag.com/errors/$error_id/events?per_page=1" 2>/dev/null)"
else
  latest_event=""
fi

# Write both to the temp file for Claude to read
printf '{"top_error": %s, "latest_event": %s}\n' \
  "${top_error:-null}" "${latest_event:-null}" > "$bugsnag_file"

run_agent "Fetch the top unresolved error from BugSnag and write a fix plan.

The BugSnag data has already been fetched and saved to $bugsnag_file. Read that file to get the error data (JSON with top_error and latest_event fields).

Step 1 — Read $bugsnag_file to load the BugSnag error and event data.

Step 2 — Read the relevant source files in this project to understand the context.

Step 3 — Write a fix plan to $MACPILOT_REPORTS/bugsnag-$(date +%Y%m%d).md with:
  - Error class and message
  - Stack trace summary
  - Affected source files
  - Root cause analysis
  - Step-by-step fix instructions

IMPORTANT: After writing the report file, stop immediately. Do not verify, re-read, or do any follow-up work." \
  --max-turns 10 \
  --allowedTools "Read Write Glob Grep"

rm -f "$bugsnag_file"
trap - EXIT INT TERM
