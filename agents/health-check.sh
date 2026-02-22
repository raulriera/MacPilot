#!/bin/sh
# health-check.sh — verifies all scheduled agents ran recently and notifies on staleness.
. "$(dirname "$0")/../lib/macpilot.sh"

# How many hours before a log entry is considered stale (default 48h)
STALE_HOURS="${HEALTH_CHECK_STALE_HOURS:-48}"

run_agent "Check the health of all MacPilot agents by inspecting their log files.

Log format: each run appends two lines to the .log file:
  [YYYY-MM-DD HH:MM:SS] Running agent: <name>
  [YYYY-MM-DD HH:MM:SS] OK (turns: N/M)   — or —   [YYYY-MM-DD HH:MM:SS] FAILED (exit N)
followed by the agent's text output and a '---' separator.

Step 1 — List all agent log files:
  ls $MACPILOT_LOGS/*.log 2>/dev/null

Step 2 — For each log file, extract the most recent run time and status:
  a) Find the last '[...] Running agent:' line:
       grep -E '^\[' <logfile> | grep 'Running agent:' | tail -1
  b) Find the last status line (OK or FAILED) that follows it:
       grep -E '^\[.*\] (OK|FAILED)' <logfile> | tail -1
  c) Parse the timestamp from that line (format: [YYYY-MM-DD HH:MM:SS]).
  d) Compute how many hours ago that was vs. now (date +%s).
  e) Classify: STALE if > $STALE_HOURS hours ago, FAILED if status line says FAILED, NO RUNS if no lines found, OK otherwise.

Step 3 — Write a health report to $MACPILOT_REPORTS/health-\$(date +%Y%m%d).md with:
  - Date of the check
  - For each agent log: agent name, last run time, hours since last run, status (OK / FAILED / STALE / NO RUNS)
  - Overall summary: number healthy, number with issues
  - Recommended actions for any agents with problems

IMPORTANT: After writing the report file, stop immediately. Do not verify, re-read, or do any follow-up work." \
  --max-turns 10 \
  --allowedTools "Bash Read Grep Write Glob"
