#!/bin/sh
# health-check.sh — verifies all scheduled agents ran recently and notifies on staleness.
. "$(dirname "$0")/../lib/macpilot.sh"

# How many hours before a log entry is considered stale (default 48h)
STALE_HOURS="${HEALTH_CHECK_STALE_HOURS:-48}"

run_agent "Check the health of all MacPilot agents by inspecting their log files.

Step 1 — List all agent log files:
  ls $MACPILOT_LOGS/*.log 2>/dev/null

Step 2 — For each log file, find the most recent 'Running agent:' timestamp:
  Use grep and stat or tail to find the last run time for each agent.
  An agent is STALE if its last run was more than $STALE_HOURS hours ago.
  An agent has ERRORS if its last completed entry shows FAILED.

Step 3 — Write a health report to $MACPILOT_REPORTS/health-\$(date +%Y%m%d).md with:
  - Date of the check
  - For each agent log: agent name, last run time, status (OK / FAILED / STALE / NO RUNS)
  - Overall summary: number healthy, number with issues
  - Recommended actions for any agents with problems

IMPORTANT: After writing the report file, stop immediately. Do not verify, re-read, or do any follow-up work." \
  --max-turns 10 \
  --allowedTools "Bash Write Glob"
