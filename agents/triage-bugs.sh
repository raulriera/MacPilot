#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

if [ -z "$PROJECT_DIR" ]; then
  echo "PROJECT_DIR not set" >&2
  notify "MacPilot: $AGENT_NAME" "PROJECT_DIR not set. Check .env or plist."
  exit 1
fi

cd "$PROJECT_DIR" || exit 1

run_agent "Fetch the top unresolved error from BugSnag and write a fix plan.

Step 1 — Get the top error:
  curl -s -H 'Authorization: token \$BUGSNAG_API_KEY' \
    'https://api.bugsnag.com/projects/'\$BUGSNAG_PROJECT_ID'/errors?sort=events&direction=desc&per_page=1'

Step 2 — Get the latest event for that error (use the error ID from step 1):
  curl -s -H 'Authorization: token \$BUGSNAG_API_KEY' \
    'https://api.bugsnag.com/errors/<ERROR_ID>/events?per_page=1'

Step 3 — Read the relevant source files in this project to understand the context.

Step 4 — Write a fix plan to $MACPILOT_REPORTS/bugsnag-$(date +%Y%m%d).md with:
  - Error class and message
  - Stack trace summary
  - Affected source files
  - Root cause analysis
  - Step-by-step fix instructions

IMPORTANT: After writing the report file, stop immediately. Do not verify, re-read, or do any follow-up work." \
  --max-turns 10 \
  --allowedTools "Read Bash Write"
