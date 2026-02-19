#!/bin/sh
# Example agent — replace with your own prompt and schedule.
. "$(dirname "$0")/../lib/macpilot.sh"

run_agent "What is today's date? Respond in one sentence." \
  --max-turns 1
