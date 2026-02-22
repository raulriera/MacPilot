# MacPilot

Scheduled autonomous Claude agents for macOS, powered by launchd and shell scripts.

## What This Is

A collection of shell scripts that run Claude Code CLI on a schedule via launchd. No app, no framework, no compilation. Each agent is a `.sh` file paired with one or more `.plist` files that tell macOS when to run it.

## Project Goals

- Run Claude agents on a schedule (daily, hourly, whatever)
- Zero dependencies beyond `claude` CLI and `jq`
- Each agent is a standalone script — easy to read, edit, copy
- Secrets and project paths live in one `.env` file, never hardcoded
- Every run is logged with timestamp and result
- Push notifications via ntfy.sh (with osascript fallback)
- Works headless on a dedicated Mac Mini — no GUI session required
- Install/uninstall with one command

## Interaction Model

Agents are fire-and-forget. They run unattended and produce **local artifacts** you review later:

- **Push notification** — via ntfy.sh if configured, plus osascript locally (always)
- **Log file** — full output in `logs/` (always)
- **Reports** — triage reports and fix plans in `reports/` (per agent)
- **Git branches** — agent creates a local branch with its changes (per agent)

Agents never take public-facing actions — no opening GitHub issues, no creating PRs, no posting comments. The repo may be public. Agents work locally and you decide what to publish.

If you need to guide an agent mid-task or have a conversation, use `claude` interactively in your terminal. Scheduled agents should be self-contained enough to run without supervision.

## How It Works

### An agent is two files

**1. A shell script** (`agents/test-xcode-project.sh`):

```sh
#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

if [ -z "$PROJECT_DIR" ]; then
  echo "PROJECT_DIR not set" >&2
  notify "MacPilot: $AGENT_NAME" "PROJECT_DIR not set. Check .env or plist."
  exit 1
fi

cd "$PROJECT_DIR" || exit 1

run_agent "Run the $TEST_PLAN test plan and propose fixes for any failures. ..." \
  --max-turns 10 \
  --allowedTools "Read Bash Write Glob Grep"
```

**2. A launchd plist** (`plists/com.macpilot.test-xcode-project.plist`):

```xml
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.macpilot.test-xcode-project</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>MACPILOT_AGENT_NAME</key>
    <string>test-xcode-project</string>
    <key>PROJECT_DIR</key>
    <string>__HOME__/Developer/MyApp</string>
    <key>TEST_PLAN</key>
    <string>AllTargets</string>
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>__MACPILOT_DIR__/agents/test-xcode-project.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>2</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>__MACPILOT_DIR__/logs/test-xcode-project.out</string>
  <key>StandardErrorPath</key>
  <string>__MACPILOT_DIR__/logs/test-xcode-project.err</string>
</dict>
</plist>
```

`install.sh` substitutes `__MACPILOT_DIR__` and `__HOME__` with real paths when installing.

### Reusing scripts across projects

A single agent script can serve multiple projects. Each plist sets its own environment variables:

- `PROJECT_DIR` — the project to operate on
- `MACPILOT_AGENT_NAME` — overrides the default name (derived from script filename) so logs, reports, and notifications are distinct
- Any agent-specific config (e.g. `TEST_PLAN`, `SIMULATOR_DESTINATION`)

For example, `test-xcode-project.sh` can test any Xcode project. Create one plist per project with different env vars — same script, separate logs and reports.

You can also override env vars inline when running manually:

```sh
PROJECT_DIR=~/Developer/OtherApp TEST_PLAN=UnitTests ./agents/test-xcode-project.sh
```

The `.env` file provides defaults. Variables already set in the environment (via inline override or plist `EnvironmentVariables`) are not overwritten by `.env`.

### Shared library

`lib/macpilot.sh` handles the boring parts every agent needs:

- **Find claude** — checks `~/.local/bin/claude`, `/usr/local/bin/claude`, `/opt/homebrew/bin/claude`
- **Load .env** — sources `config/.env` to inject API keys and defaults (skips vars already set, expands `~` to `$HOME`)
- **Set up PATH** — prepends Homebrew and Xcode tool directories so launchd jobs find everything
- **Agent name** — uses `MACPILOT_AGENT_NAME` if set, otherwise derives from script filename
- **Clear nesting vars** — unsets `CLAUDECODE` / `CLAUDE_CODE_ENTRYPOINT` so agents can be tested from within Claude Code
- **Sync repo** — `sync_repo` fetches origin, checks out the default branch, and pulls with `--ff-only`. Fails if the working tree is dirty. Project-scoped agents call this after `cd "$PROJECT_DIR"` to stay up to date with the remote.
- **Call claude** — runs `claude -p "..." --output-format json --no-session-persistence` with sensible defaults and a timeout
- **Parse output** — pipes through `jq` to extract the text response
- **Log** — appends timestamped results to the agent's log file
- **Notify** — sends push notification via ntfy.sh (if `NTFY_TOPIC` is set) and attempts osascript locally

Agents source this library and call `run_agent "prompt"` with optional flag overrides. One function, one line.

### Claude CLI flags

| Flag | Default | Purpose |
|---|---|---|
| `-p "prompt"` | (required) | Non-interactive mode |
| `--output-format json` | always | Structured output for `jq` parsing |
| `--model sonnet` | sonnet | Model selection (sonnet, opus, haiku) |
| `--max-turns 10` | 10 | Limit agentic turns |
| `--timeout 300` | 300 (5 min) | Kill the process if it exceeds this many seconds |
| `--allowedTools` | per agent | Pre-approve tools to avoid prompts |
| `--no-session-persistence` | always | Don't clutter Claude's session list |
| `--append-system-prompt` | set by lib | Inject "execute without asking" context |

### Project-scoped agents

Agents that work inside a project directory read `PROJECT_DIR` from the environment:

```sh
#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

if [ -z "$PROJECT_DIR" ]; then
  echo "PROJECT_DIR not set" >&2
  notify "MacPilot: $AGENT_NAME" "PROJECT_DIR not set. Check .env or plist."
  exit 1
fi

cd "$PROJECT_DIR" || exit 1
sync_repo || exit 1

run_agent "Find all TODO comments, fix them, and summarize what you did." \
  --max-turns 10 \
  --allowedTools "Read Edit Write Bash"
```

Set `PROJECT_DIR` in `config/.env` for a default, or override per-plist or inline.

## Project Structure

```
MacPilot/
  agents/              # One .sh file per agent
    example.sh         # Example agent (ships as a template)
    triage-bugs.sh     # BugSnag error triage
    triage-github.sh   # GitHub issues triage
    test-xcode-project.sh  # Run Xcode test plans
    improve.sh         # Self-improving meta-agent (proposes changes on a branch)
    health-check.sh    # Checks all agents ran recently and flags failures
  plists/              # One .plist per project/schedule
    com.macpilot.example.plist
    com.macpilot.triage-bugs.plist
    com.macpilot.test-xcode-project.plist
    com.macpilot.rotate-logs.plist
    com.macpilot.improve.plist
    com.macpilot.health-check.plist
  lib/
    macpilot.sh        # Shared library (find claude, load env, run, parse, log, notify)
    rotate-logs.sh     # Deletes logs/reports older than 30 days
  config/
    .env.example       # Template for secrets and project paths
    goals.md           # User-directed improvement goals for the meta-agent
  logs/                # Execution logs (one .log and .err per agent)
  reports/             # Agent output (triage reports, fix plans, etc.)
  install.sh           # Substitutes paths, copies plists to ~/Library/LaunchAgents/, loads them
  uninstall.sh         # Unloads and removes plists
  CLAUDE.md
```

## Setup

```sh
# 1. Clone
git clone ... && cd MacPilot

# 2. Add secrets and project paths
cp config/.env.example config/.env
# Edit config/.env with your API keys and PROJECT_DIR
chmod 600 config/.env

# 3. Install schedules
./install.sh
```

`install.sh` copies every plist in `plists/` to `~/Library/LaunchAgents/`, substituting `__MACPILOT_DIR__` and `__HOME__` with real paths, then loads them with `launchctl bootstrap`.

`uninstall.sh` reverses this — unloads and removes the plists.

## Off-Limits Files

These files exist as templates and references. Agents (including the improve agent) must never modify, schedule, or create plists for them:

- `agents/example.sh` — ships as a starter template for new users
- `config/.env` — contains secrets and user-specific paths
- `config/.env.example` — template showing available config variables (adding new documented variables is OK)
- Any file whose sole purpose is documentation or demonstration

## Adding a New Agent

1. Create `agents/my-task.sh` — source the lib, guard on required env vars, call `run_agent` with your prompt
2. Create `plists/com.macpilot.my-task.plist` — set the schedule and any `EnvironmentVariables`
3. Run `./install.sh` to activate it

To reuse an existing script for a different project, just create another plist with different `EnvironmentVariables` pointing to the same script.

## Writing Prompts

- **Be explicit about steps** — numbered steps with exact commands work better than vague instructions
- **End with a stop instruction** — "After writing the report file, stop immediately. Do not verify, re-read, or do any follow-up work." prevents Claude from burning extra turns
- **Keep `--max-turns` tight** — 10 is a good default; raise only if the task genuinely needs more steps
- **Pipe verbose output through `tail`** — e.g. `xcodebuild ... 2>&1 | tail -50` to avoid flooding Claude's context

## Headless Deployment (Mac Mini)

MacPilot can run on a dedicated Mac Mini with auto-login and no interactive GUI session.

### Notifications via ntfy.sh

Set `NTFY_TOPIC` in `config/.env` to receive push notifications on your phone or main machine. The `notify()` function in `lib/macpilot.sh` POSTs to `${NTFY_SERVER:-https://ntfy.sh}/$NTFY_TOPIC`. Failure notifications are sent with `high` priority.

osascript still fires as a local fallback — it silently fails without a GUI, so no harm on headless machines.

### PATH handling

launchd jobs inherit a minimal PATH. `lib/macpilot.sh` prepends `/opt/homebrew/bin`, `/opt/homebrew/sbin`, `/usr/local/bin`, and the Xcode developer tools directory (via `xcode-select -p`) so that agents and Claude's Bash tool can find `jq`, `git`, `xcodebuild`, etc.

### Running agents from within Claude Code

`lib/macpilot.sh` unsets `CLAUDECODE` and `CLAUDE_CODE_ENTRYPOINT` before invoking the Claude CLI, preventing "cannot be launched inside another session" errors. This makes local testing straightforward.

## Log Rotation

`lib/rotate-logs.sh` deletes files in `logs/` and `reports/` older than 30 days (configurable via `MACPILOT_LOG_RETENTION_DAYS` or a command-line argument). A weekly plist (`com.macpilot.rotate-logs.plist`) runs it every Sunday at 3 AM.

Manual run: `lib/rotate-logs.sh [days]`

## Security

- **No secrets or paths in scripts** — everything goes through `config/.env` (gitignored, `chmod 600`) or plist `EnvironmentVariables`
- **No network exposure** — no servers, no ports, no listeners
- **Claude CLI handles auth** — no tokens stored by MacPilot
- **`--max-turns` on every invocation** — prevents runaway agents
- **`--timeout` on every invocation** — kills hanging processes (default 5 minutes)
- **Logs are local** — no telemetry, no external reporting

## Dependencies

| Tool | Purpose | Install |
|---|---|---|
| `claude` | Claude Code CLI | Already installed |
| `jq` | JSON parsing | `brew install jq` |
| `curl` | ntfy.sh notifications | Built into macOS |
| `osascript` | Local notifications (fallback) | Built into macOS |

## Example Agents

### Nightly Xcode test run (2 AM)

Runs an Xcode test plan, analyzes failures, and writes a fix plan. Reusable across projects via env vars.

```sh
PROJECT_DIR=~/Developer/MyApp TEST_PLAN=AllTargets ./agents/test-xcode-project.sh
```

**You wake up:** notification says "All 295 tests pass" or "3 failures — fix plan written." You open `reports/test-xcode-project-20260220.md` and decide what to act on.

### Daily BugSnag triage → code plan (8 AM)

Fetches the top error, analyzes it in the context of the actual codebase, and writes a fix plan to a local file.

```sh
PROJECT_DIR=~/Developer/MyApp ./agents/triage-bugs.sh
```

### GitHub issues triage

Fetches all open issues, groups duplicates, ranks by severity, and writes a prioritized triage report.

```sh
./agents/triage-github.sh
```

### Weekly self-improvement (Sunday 4 AM)

Reads `config/goals.md`, recent logs, and reports, then proposes improvements to MacPilot itself on a git branch.

```sh
./agents/improve.sh
```

**You review:** `git diff main..improve/20260222`, read `reports/improve-20260222.md`, cherry-pick or merge what you like.

### Daily health check (9 AM)

Inspects all agent log files for stale or failed runs and writes a status report. Configure staleness threshold with `HEALTH_CHECK_STALE_HOURS` (default 48).

```sh
./agents/health-check.sh
```

## References

- [Claude Code CLI Reference](https://docs.anthropic.com/en/docs/claude-code/cli-usage)
- [launchd.plist man page](x-man-page://5/launchd.plist)
- [launchctl man page](x-man-page://1/launchctl)
