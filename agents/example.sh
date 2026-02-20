#!/bin/sh
# Example agent — useful for testing setup and notifications.
. "$(dirname "$0")/../lib/macpilot.sh"

run_agent "What is today's date? Respond in one sentence." \
  --max-turns 1 \
  --model haiku
