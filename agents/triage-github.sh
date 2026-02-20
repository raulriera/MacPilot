#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

run_agent "Triage all open issues in the GitHub repo odontome/app.

Step 1 — Fetch all open issues:
  gh issue list --repo odontome/app --state open --limit 100 --json number,title,body,labels,createdAt,author

Step 2 — Analyze every issue:
  - Group duplicates together (note which ones are dupes of which)
  - Flag issues that are non-actionable, stale, or too vague
  - Rank the remaining issues by severity and impact

Step 3 — Write a triage report to $MACPILOT_REPORTS/github-\$(date +%Y%m%d).md with:
  - Issues recommended to close (duplicates, non-actionable) with reasons
  - The single top-priority issue: number, title, and why it matters
  - Root cause analysis of the top issue (if enough context exists)
  - Step-by-step plan to address it" \
  --max-turns 15 \
  --allowedTools "Bash Write"
