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
- macOS notifications on completion or failure
- Install/uninstall with one command

## Interaction Model

Agents are fire-and-forget. They run unattended and produce **local artifacts** you review later:

- **macOS notification** — a summary of what happened (always)
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
- **Agent name** — uses `MACPILOT_AGENT_NAME` if set, otherwise derives from script filename
- **Call claude** — runs `claude -p "..." --output-format json --no-session-persistence` with sensible defaults and a timeout
- **Parse output** — pipes through `jq` to extract the text response
- **Log** — appends timestamped results to the agent's log file
- **Notify** — sends a macOS notification via `osascript` on success or failure

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
  plists/              # One .plist per project/schedule
    com.macpilot.example.plist
    com.macpilot.triage-bugs.plist
    com.macpilot.test-xcode-project.plist
  lib/
    macpilot.sh        # Shared library (find claude, load env, run, parse, log, notify)
  config/
    .env.example       # Template for secrets and project paths
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
| `osascript` | macOS notifications | Built into macOS |

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

## References

- [Claude Code CLI Reference](https://docs.anthropic.com/en/docs/claude-code/cli-usage)
- [launchd.plist man page](x-man-page://5/launchd.plist)
- [launchctl man page](x-man-page://1/launchctl)
