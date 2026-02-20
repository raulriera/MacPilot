#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

if [ -z "$PROJECT_DIR" ]; then
  echo "PROJECT_DIR not set" >&2
  notify "MacPilot: $AGENT_NAME" "PROJECT_DIR not set. Check .env or plist."
  exit 1
fi

if [ -z "$TEST_PLAN" ]; then
  echo "TEST_PLAN not set" >&2
  notify "MacPilot: $AGENT_NAME" "TEST_PLAN not set. Check .env or plist."
  exit 1
fi

cd "$PROJECT_DIR" || exit 1

# Optional: SIMULATOR_DESTINATION defaults to iPhone 16
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:-iPhone 16}"

run_agent "Run the Xcode tests for this project and propose fixes for any failures.

Step 1 — Run the tests:
  xcodebuild test \
    -scheme \$(xcodebuild -list -json | jq -r '.project.schemes[0]') \
    -testPlan $TEST_PLAN \
    -destination 'platform=iOS Simulator,name=$SIMULATOR_DESTINATION' \
    2>&1 | tail -50

  If the build or tests fail to start, check 'xcodebuild -list' for the correct scheme name.

Step 2 — Analyze results:
  If all tests pass, write a short summary to $MACPILOT_REPORTS/${AGENT_NAME}-\$(date +%Y%m%d).md confirming the green build.
  If any tests fail, continue to step 3.

Step 3 — Diagnose failures:
  For each failing test:
  - Read the test file and the source file under test
  - Identify the root cause (logic bug, API change, missing mock, etc.)

Step 4 — Write a fix plan:
  Write to $MACPILOT_REPORTS/${AGENT_NAME}-\$(date +%Y%m%d).md with:
  - Date and scheme used
  - Total tests run, passed, failed
  - For each failure: test name, assertion that failed, root cause, and proposed fix with code snippets" \
  --max-turns 20 \
  --timeout 900 \
  --allowedTools "Read Bash Write Glob Grep"
