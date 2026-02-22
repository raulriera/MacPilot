#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

if [ -z "$GITHUB_REPO" ]; then
  echo "GITHUB_REPO not set" >&2
  notify "MacPilot: $AGENT_NAME" "GITHUB_REPO not set. Check .env or plist." "high"
  exit 1
fi

# Verify gh is authenticated before spending turns on it
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI not authenticated" >&2
  notify "MacPilot: $AGENT_NAME" "gh CLI not authenticated. Run: gh auth login" "high"
  exit 1
fi

# Fetch issues in shell (outside Claude) to avoid passing untrusted data
# through a prompt that has Bash access.
issues_file="$(mktemp)"
trap 'rm -f "$issues_file"' EXIT INT TERM

gh issue list --repo "$GITHUB_REPO" --state open --limit 100 \
  --json number,title,body,labels,createdAt,author > "$issues_file" 2>/dev/null

if [ ! -s "$issues_file" ]; then
  echo "No open issues or failed to fetch from $GITHUB_REPO" >&2
  notify "MacPilot: $AGENT_NAME" "No open issues or fetch failed for $GITHUB_REPO."
  rm -f "$issues_file"
  trap - EXIT INT TERM
  exit 0
fi

run_agent "Triage all open issues in the GitHub repo $GITHUB_REPO.

The issues have already been fetched and saved to $issues_file. Read that file to get the issue data (JSON array with number, title, body, labels, createdAt, author).

Step 1 — Read $issues_file to load all open issues.

Step 2 — Analyze every issue:
  - Group duplicates together (note which ones are dupes of which)
  - Flag issues that are non-actionable, stale, or too vague
  - Rank the remaining issues by severity and impact

Step 3 — Write a triage report to $MACPILOT_REPORTS/github-\$(date +%Y%m%d).md with:
  - Issues recommended to close (duplicates, non-actionable) with reasons
  - The single top-priority issue: number, title, and why it matters
  - Root cause analysis of the top issue (if enough context exists)
  - Step-by-step plan to address it

IMPORTANT: After writing the report file, stop immediately. Do not verify, re-read, or do any follow-up work." \
  --max-turns 10 \
  --allowedTools "Read Write"

rm -f "$issues_file"
trap - EXIT INT TERM
