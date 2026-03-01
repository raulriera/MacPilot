#!/bin/sh
# test.sh — lightweight test suite for MacPilot
# Runs in ~1 second. No claude, no launchctl, no network.
# Usage: ./test.sh

MACPILOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Setup ---

test_tmp="$(mktemp -d)"
trap 'rm -rf "$test_tmp"' EXIT INT TERM

passed=0
failed=0
total=0

# --- Helpers ---

assert_eq() {
  desc="$1"; expected="$2"; actual="$3"
  total=$((total + 1))
  if [ "$expected" = "$actual" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf "  FAIL: %s\n    expected: %s\n    actual:   %s\n" "$desc" "$expected" "$actual"
  fi
}

assert_ok() {
  desc="$1"; shift
  total=$((total + 1))
  if "$@" >/dev/null 2>&1; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf "  FAIL: %s (expected exit 0)\n" "$desc"
  fi
}

assert_fail() {
  desc="$1"; shift
  total=$((total + 1))
  if "$@" >/dev/null 2>&1; then
    failed=$((failed + 1))
    printf "  FAIL: %s (expected nonzero exit)\n" "$desc"
  else
    passed=$((passed + 1))
  fi
}

# ============================================================
# 1. Syntax validation
# ============================================================
echo "--- Syntax validation ---"

for f in "$MACPILOT_DIR"/agents/*.sh "$MACPILOT_DIR"/lib/*.sh \
         "$MACPILOT_DIR"/install.sh "$MACPILOT_DIR"/uninstall.sh \
         "$MACPILOT_DIR"/test.sh; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  assert_ok "sh -n $name" sh -n "$f"
done

# ============================================================
# 2. Plist validation
# ============================================================
echo "--- Plist validation ---"

for f in "$MACPILOT_DIR"/plists/*.plist; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  assert_ok "plutil -lint $name" plutil -lint "$f"
done

# ============================================================
# 3. Selection logic (is_selected)
# ============================================================
echo "--- Selection logic ---"

# Re-define is_selected from install.sh
is_selected() {
  if "$select_all"; then return 0; fi
  for _s in $selection; do
    [ "$_s" = "$1" ] && return 0
  done
  return 1
}

# select_all=true matches everything
select_all=true
selection=""
assert_ok "select_all matches 1" is_selected 1
assert_ok "select_all matches 99" is_selected 99

# Space-separated selection
select_all=false
selection="1 3 5"
assert_ok "space-sep matches 1" is_selected 1
assert_ok "space-sep matches 3" is_selected 3
assert_ok "space-sep matches 5" is_selected 5
assert_fail "space-sep rejects 2" is_selected 2
assert_fail "space-sep rejects 4" is_selected 4

# Single item
selection="2"
assert_ok "single item matches 2" is_selected 2
assert_fail "single item rejects 1" is_selected 1

# Empty selection
selection=""
assert_fail "empty selection rejects 1" is_selected 1

# ============================================================
# 4. Comma normalization (the actual bug)
# ============================================================
echo "--- Comma normalization ---"

# After normalization, commas become spaces
raw="1,2,3"
selection="$(echo "$raw" | tr ',' ' ')"
select_all=false
assert_ok "normalized 1,2,3 matches 1" is_selected 1
assert_ok "normalized 1,2,3 matches 2" is_selected 2
assert_ok "normalized 1,2,3 matches 3" is_selected 3

# Commas + spaces also work
raw="1, 2, 3"
selection="$(echo "$raw" | tr ',' ' ')"
assert_ok "normalized '1, 2, 3' matches 1" is_selected 1
assert_ok "normalized '1, 2, 3' matches 2" is_selected 2
assert_ok "normalized '1, 2, 3' matches 3" is_selected 3

# Without normalization, "1,2,3" is treated as a single token — regression proof
selection="1,2,3"
assert_ok "un-normalized matches literal '1,2,3' at 1,2,3" is_selected "1,2,3"
assert_fail "un-normalized rejects 2" is_selected 2

# ============================================================
# 5. Placeholder substitution
# ============================================================
echo "--- Placeholder substitution ---"

# Create a temp file with placeholders
cat > "$test_tmp/test.plist" <<'EOF'
<string>__MACPILOT_DIR__/agents/example.sh</string>
<string>__HOME__/Library/LaunchAgents</string>
EOF

# Run the same sed from install.sh
fake_macpilot="/opt/macpilot"
fake_home="/Users/testuser"
result="$(sed -e "s|__MACPILOT_DIR__|$fake_macpilot|g" -e "s|__HOME__|$fake_home|g" "$test_tmp/test.plist")"

assert_eq "MACPILOT_DIR substituted" \
  "<string>/opt/macpilot/agents/example.sh</string>" \
  "$(echo "$result" | head -1)"

assert_eq "HOME substituted" \
  "<string>/Users/testuser/Library/LaunchAgents</string>" \
  "$(echo "$result" | tail -1)"

# Verify each real plist contains __MACPILOT_DIR__ (would be broken if missing)
for f in "$MACPILOT_DIR"/plists/*.plist; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  total=$((total + 1))
  if grep -q "__MACPILOT_DIR__" "$f"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    printf "  FAIL: %s missing __MACPILOT_DIR__ placeholder\n" "$name"
  fi
done

# ============================================================
# 6. .env parsing
# ============================================================
echo "--- .env parsing ---"

# Write the parse_env function to a temp file so each test can source it cleanly.
# This mirrors the parsing loop from lib/macpilot.sh lines 62-82.
cat > "$test_tmp/parse_env.sh" <<'PARSE'
parse_env() {
  _penv_file="$1"
  while IFS= read -r _penv_line || [ -n "$_penv_line" ]; do
    case "$_penv_line" in
      \#*|"") continue ;;
    esac
    _penv_key="${_penv_line%%=*}"
    _penv_val="${_penv_line#*=}"
    case "$_penv_key" in
      *[!A-Za-z0-9_]*|[0-9]*|"") continue ;;
    esac
    case "$_penv_val" in
      \"*\") _penv_val="${_penv_val#\"}"; _penv_val="${_penv_val%\"}" ;;
      \'*\') _penv_val="${_penv_val#\'}"; _penv_val="${_penv_val%\'}" ;;
    esac
    case "$_penv_val" in
      "~/"*) _penv_val="$HOME/${_penv_val#"~/"}" ;;
      "~")   _penv_val="$HOME" ;;
    esac
    if ! printenv "$_penv_key" >/dev/null 2>&1; then
      export "$_penv_key=$_penv_val"
    fi
  done < "$_penv_file"
}
PARSE

# Comments and blank lines skipped
cat > "$test_tmp/env1" <<'EOF'
# This is a comment
ENVTEST_FOO=bar

ENVTEST_BAZ=qux
EOF
val="$(env -i HOME="$HOME" PATH="$PATH" sh -c ". '$test_tmp/parse_env.sh'; parse_env '$test_tmp/env1'; echo \"\$ENVTEST_FOO|\$ENVTEST_BAZ\"")"
assert_eq "comments/blanks skipped, values parsed" "bar|qux" "$val"

# Double-quoted values stripped
cat > "$test_tmp/env2" <<'EOF'
ENVTEST_DQ="hello world"
EOF
val="$(env -i HOME="$HOME" PATH="$PATH" sh -c ". '$test_tmp/parse_env.sh'; parse_env '$test_tmp/env2'; echo \"\$ENVTEST_DQ\"")"
assert_eq "double-quoted value stripped" "hello world" "$val"

# Single-quoted values stripped
cat > "$test_tmp/env3" <<'EOF'
ENVTEST_SQ='single quoted'
EOF
val="$(env -i HOME="$HOME" PATH="$PATH" sh -c ". '$test_tmp/parse_env.sh'; parse_env '$test_tmp/env3'; echo \"\$ENVTEST_SQ\"")"
assert_eq "single-quoted value stripped" "single quoted" "$val"

# Tilde expansion
cat > "$test_tmp/env4" <<'EOF'
ENVTEST_TILDE=~/projects
EOF
val="$(env -i HOME="$HOME" PATH="$PATH" sh -c ". '$test_tmp/parse_env.sh'; parse_env '$test_tmp/env4'; echo \"\$ENVTEST_TILDE\"")"
assert_eq "tilde expanded" "$HOME/projects" "$val"

# Invalid variable names rejected
cat > "$test_tmp/env5" <<'EOF'
123start=bad
has-dash=bad
ENVTEST_GOOD=kept
EOF
val="$(env -i HOME="$HOME" PATH="$PATH" sh -c ". '$test_tmp/parse_env.sh'; parse_env '$test_tmp/env5'; echo \"\${ENVTEST_GOOD:-}\"")"
assert_eq "invalid names rejected, valid kept" "kept" "$val"

# Existing env vars not overwritten (precedence)
cat > "$test_tmp/env6" <<'EOF'
ENVTEST_PRE=from_file
EOF
val="$(env -i HOME="$HOME" PATH="$PATH" ENVTEST_PRE=from_env sh -c ". '$test_tmp/parse_env.sh'; parse_env '$test_tmp/env6'; echo \"\$ENVTEST_PRE\"")"
assert_eq "existing env var not overwritten" "from_env" "$val"

# ============================================================
# 7. Agent env var guards
# ============================================================
echo "--- Agent env var guards ---"

# Create a stub macpilot.sh that defines no-op functions
# so agents can source it without needing claude, jq, etc.
mkdir -p "$test_tmp/lib" "$test_tmp/agents" "$test_tmp/logs" "$test_tmp/reports" "$test_tmp/tmp"

cat > "$test_tmp/lib/macpilot.sh" <<'STUB'
MACPILOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MACPILOT_LOGS="$MACPILOT_DIR/logs"
MACPILOT_REPORTS="$MACPILOT_DIR/reports"
MACPILOT_TMP="$MACPILOT_DIR/tmp"
AGENT_NAME="${MACPILOT_AGENT_NAME:-$(basename "$0" .sh)}"
notify() { :; }
sync_repo() { :; }
run_agent() { :; }
STUB

# Copy agent scripts into the temp dir (relative source path resolves to our stub)
for agent in test-xcode-project triage-bugs triage-github digest; do
  cp "$MACPILOT_DIR/agents/$agent.sh" "$test_tmp/agents/$agent.sh"
  chmod +x "$test_tmp/agents/$agent.sh"
done

# test-xcode-project.sh without PROJECT_DIR
assert_fail "test-xcode-project fails without PROJECT_DIR" \
  env -i HOME="$HOME" PATH="$PATH" sh "$test_tmp/agents/test-xcode-project.sh"

# triage-bugs.sh without PROJECT_DIR
assert_fail "triage-bugs fails without PROJECT_DIR" \
  env -i HOME="$HOME" PATH="$PATH" sh "$test_tmp/agents/triage-bugs.sh"

# triage-bugs.sh with PROJECT_DIR but without BUGSNAG_API_KEY
assert_fail "triage-bugs fails without BUGSNAG_API_KEY" \
  env -i HOME="$HOME" PATH="$PATH" PROJECT_DIR=/tmp sh "$test_tmp/agents/triage-bugs.sh"

# triage-bugs.sh with PROJECT_DIR + BUGSNAG_API_KEY but without BUGSNAG_PROJECT_ID
assert_fail "triage-bugs fails without BUGSNAG_PROJECT_ID" \
  env -i HOME="$HOME" PATH="$PATH" PROJECT_DIR=/tmp BUGSNAG_API_KEY=x sh "$test_tmp/agents/triage-bugs.sh"

# triage-github.sh without GITHUB_REPO
assert_fail "triage-github fails without GITHUB_REPO" \
  env -i HOME="$HOME" PATH="$PATH" sh "$test_tmp/agents/triage-github.sh"

# digest.sh without DIGEST_TOPICS
assert_fail "digest fails without DIGEST_TOPICS" \
  env -i HOME="$HOME" PATH="$PATH" sh "$test_tmp/agents/digest.sh"

# ============================================================
# Summary
# ============================================================
echo ""
echo "$passed/$total passed"

if [ "$failed" -gt 0 ]; then
  echo "$failed test(s) FAILED"
  exit 1
fi
