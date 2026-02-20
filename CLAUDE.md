# MacPilot

Scheduled autonomous Claude agents for macOS, powered by launchd and shell scripts.

## What This Is

A collection of shell scripts that run Claude Code CLI on a schedule via launchd. No app, no framework, no compilation. Each agent is a `.sh` file paired with a `.plist` that tells macOS when to run it.

## Project Goals

- Run Claude agents on a schedule (daily, hourly, whatever)
- Zero dependencies beyond `claude` CLI and `jq`
- Each agent is a standalone script — easy to read, edit, copy
- Secrets live in one `.env` file, never hardcoded
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

**1. A shell script** (`agents/triage-bugs.sh`):

```sh
#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

run_agent "Fetch the top error from BugSnag using the BUGSNAG_API_KEY env var. \
Analyze the stack trace and summarize the fix in one paragraph." \
  --max-turns 5
```

**2. A launchd plist** (`plists/com.macpilot.triage-bugs.plist`):

```xml
<plist version="1.0">
<dict>
  <key>Label</key><string>com.macpilot.triage-bugs</string>
  <key>ProgramArguments</key>
  <array><string>/path/to/agents/triage-bugs.sh</string></array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>8</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>/path/to/logs/triage-bugs.log</string>
  <key>StandardErrorPath</key><string>/path/to/logs/triage-bugs.err</string>
</dict>
</plist>
```

That's it. macOS runs the script at 8 AM. The script calls Claude, logs the result, and sends a notification.

### Shared library

`lib/macpilot.sh` handles the boring parts every agent needs:

- **Find claude** — checks `~/.local/bin/claude`, `/usr/local/bin/claude`, `/opt/homebrew/bin/claude`
- **Load .env** — sources `config/.env` to inject API keys into the environment
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

For agents that work inside a project directory (code review, TODO cleanup, etc.), the script `cd`s into the project before calling Claude:

```sh
#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

cd ~/Developer/MyApp || exit 1

run_agent "Find all TODO comments, fix them, and summarize what you did." \
  --max-turns 15 \
  --allowedTools "Read Edit Write Bash"
```

Claude's built-in tools (Read, Edit, Write, Bash) operate relative to the working directory.

## Project Structure

```
MacPilot/
  agents/              # One .sh file per agent
    example.sh         # Example agent (ships as a template)
  plists/              # One .plist per agent (launchd schedules)
    com.macpilot.example.plist
  lib/
    macpilot.sh        # Shared library (find claude, load env, run, parse, log, notify)
  config/
    .env.example       # Template for secrets
  logs/                # Execution logs (one .log and .err per agent)
  reports/             # Agent output (triage reports, fix plans, etc.)
  install.sh           # Symlinks plists to ~/Library/LaunchAgents/ and loads them
  uninstall.sh         # Unloads and removes symlinks
  CLAUDE.md
```

## Setup

```sh
# 1. Clone
git clone ... && cd MacPilot

# 2. Add secrets
cp config/.env.example config/.env
# Edit config/.env with your API keys
chmod 600 config/.env

# 3. Install schedules
./install.sh
```

`install.sh` symlinks every plist in `plists/` to `~/Library/LaunchAgents/`, substituting the correct absolute paths, then loads them with `launchctl load`.

`uninstall.sh` reverses this — unloads and removes the symlinks.

## Adding a New Agent

1. Create `agents/my-task.sh` — source the lib, call `run_agent` with your prompt
2. Create `plists/com.macpilot.my-task.plist` — set the schedule
3. Run `./install.sh` to activate it

## Security

- **No API keys in scripts** — everything goes through `config/.env`, which is `.gitignore`d and `chmod 600`
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

### Daily BugSnag triage → code plan (8 AM)

The flagship workflow. Fetches the top error, analyzes it in the context of the actual codebase, and writes a fix plan to a local file.

```sh
#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

cd ~/Developer/MyApp || exit 1

run_agent "Use curl to fetch the top unresolved error from BugSnag \
(API key is in BUGSNAG_API_KEY env var). Read the relevant source files \
in this project to understand the context. Write a fix plan to \
\$MACPILOT_REPORTS/bugsnag-\$(date +%Y%m%d).md with: the error summary, affected files, \
root cause analysis, and step-by-step fix instructions." \
  --max-turns 10 \
  --allowedTools "Read Bash Write"
```

**You arrive at 9 AM:** notification says "BugSnag triage done." You open `PLAN-bugsnag-20260219.md` and decide what to act on.

### Weekly dependency audit (Monday 9 AM)

```sh
#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

cd ~/Developer/MyApp || exit 1

run_agent "Check for outdated dependencies. List any with known \
security vulnerabilities. Summarize what should be updated and why." \
  --max-turns 8 \
  --allowedTools "Read Bash"
```

### Hourly git status check

```sh
#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

cd ~/Developer/MyApp || exit 1

run_agent "Run git status. If there are uncommitted changes older than \
24 hours, send a notification reminding me to commit or stash." \
  --max-turns 3 \
  --allowedTools "Bash"
```

## References

- [Claude Code CLI Reference](https://docs.anthropic.com/en/docs/claude-code/cli-usage)
- [launchd.plist man page](x-man-page://5/launchd.plist)
- [launchctl man page](x-man-page://1/launchctl)
