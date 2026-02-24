#!/bin/sh
# Required: DIGEST_TOPICS — comma-separated topics (e.g. "AI LLM,Swift iOS development")
# Optional: DIGEST_REDDIT_LIMIT — Reddit posts per topic (default: 25)
# Optional: DIGEST_HN_LIMIT — HN stories per topic (default: 30)
. "$(dirname "$0")/../lib/macpilot.sh"

if [ -z "$DIGEST_TOPICS" ]; then
  echo "DIGEST_TOPICS not set" >&2
  notify "MacPilot: $AGENT_NAME" "DIGEST_TOPICS not set. Check .env or plist." "high"
  exit 1
fi

reddit_limit="${DIGEST_REDDIT_LIMIT:-25}"
hn_limit="${DIGEST_HN_LIMIT:-30}"
today="$(date +%Y%m%d)"
week_ago="$(date -v-7d +%s)"

# Fetch data for all topics upfront in shell (keeps untrusted data out of
# Claude's Bash tool). Builds a manifest string that tells Claude where
# each topic's data and report files live.
topic_manifest=""
data_files=""

IFS=','
for topic in $DIGEST_TOPICS; do
  # Trim leading/trailing whitespace
  topic="$(echo "$topic" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$topic" ] && continue

  # Create a slug for filenames (lowercase, spaces to hyphens)
  slug="$(printf '%s' "$topic" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"

  echo "--- Fetching data for topic: $topic (slug: $slug) ---"

  # Write data inside tmp/ so Claude's sandboxed tools can read it
  data_file="$MACPILOT_TMP/digest-${slug}-data.json"
  data_files="$data_files $data_file"

  # Fetch Reddit data (percent-encode the topic for safe URL use)
  encoded_topic="$(printf '%s' "$topic" | jq -sRr @uri)"
  reddit_data="$(curl -sf -A "MacPilot/1.0" \
    "https://www.reddit.com/search.json?q=${encoded_topic}&t=week&sort=top&limit=${reddit_limit}" 2>/dev/null || true)"

  # Fetch Hacker News data
  hn_data="$(curl -sf \
    "https://hn.algolia.com/api/v1/search?query=${encoded_topic}&tags=story&numericFilters=created_at_i%3E${week_ago}&hitsPerPage=${hn_limit}" 2>/dev/null || true)"

  # Write both to the temp file for Claude to read
  printf '{"reddit": %s, "hackernews": %s}\n' \
    "${reddit_data:-null}" "${hn_data:-null}" > "$data_file"

  report_file="$MACPILOT_REPORTS/digest-${slug}-${today}.md"

  topic_manifest="${topic_manifest}
- Topic: \"$topic\", Data: $data_file, Report: $report_file"
done
unset IFS

run_agent "Write weekly digest reports for multiple topics using sub-agents.

Launch one Task sub-agent PER TOPIC, all in parallel. Here are the topics:
$topic_manifest

For each topic above, launch a Task sub-agent (subagent_type: general-purpose) with a prompt that includes ALL of the following instructions:

1. Read the data file (path given below) to load the Reddit and Hacker News JSON data (fields: reddit, hackernews).
2. Analyze and deduplicate posts that appear on both sources.
3. Write EXACTLY ONE markdown file to the report path (given below) with this structure:

# Weekly Digest: <Topic Name>
**Week of $(date +%Y-%m-%d)**

## Trending Themes
3-5 patterns or recurring topics you noticed across the posts.

## Top Stories
Pick the 5 most significant items. For each:
- Title with link to the original URL
- Source (Reddit/HN) and subreddit if Reddit
- Engagement (upvotes, comments)
- One-line summary of why it matters

CONSTRAINTS — include these in every sub-agent prompt:
- Write ONLY the single report .md file specified. Do NOT create any other files (no scripts, no helpers, no temporary files).
- Do NOT use Bash. Do NOT write code. Your only job is to read the data and write the report.
- After writing the report file, stop immediately.

IMPORTANT: Launch ALL sub-agents in a single message so they run in parallel. After all reports are written, stop immediately." \
  --max-turns 10 \
  --timeout 600 \
  --allowedTools "Read Write Task"

# Clean up data files (trap is unreliable — run_agent overwrites it)
rm -f "$MACPILOT_TMP"/digest-*-data.json
