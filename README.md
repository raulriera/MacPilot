# MacPilot

Scheduled autonomous Claude agents for macOS. Shell scripts + launchd, nothing else.

Each agent is a `.sh` file with a prompt and a `.plist` that tells macOS when to run it. Agents produce local artifacts — log files, reports, git branches — and send you a push notification when done. You review the results and decide what to publish.

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code/cli-usage) (`claude`)
- [jq](https://jqlang.github.io/jq/) (`brew install jq`)
- macOS (uses launchd for scheduling)

## Setup

```sh
git clone https://github.com/raulriera/MacPilot.git
cd MacPilot

# Create your config from the template
cp config/.env.example config/.env
chmod 600 config/.env
```

Edit `config/.env` with your values:

```sh
# Push notifications (required for headless, optional locally)
NTFY_TOPIC=your-topic-name

# Default project for project-scoped agents
PROJECT_DIR=~/Developer/MyApp

# API keys for specific agents
# BUGSNAG_API_KEY=...
# GITHUB_TOKEN=...
```

Install the schedules:

```sh
./install.sh
```

This copies each plist to `~/Library/LaunchAgents/`, substitutes paths, and loads them into launchd. To remove everything: `./uninstall.sh`.

## Notifications

If `NTFY_TOPIC` is set in your `.env`, agents send push notifications via [ntfy.sh](https://ntfy.sh). Install the ntfy app on your phone or subscribe from your main machine. Failures are sent with high priority.

osascript notifications also fire as a local fallback (silently ignored on headless machines).

You can self-host ntfy and point to it with `NTFY_SERVER=https://ntfy.example.com`.

## Adding an agent

**1. Write the script** — `agents/my-task.sh`:

```sh
#!/bin/sh
. "$(dirname "$0")/../lib/macpilot.sh"

run_agent "Summarize the git log from the past week." \
  --max-turns 3 \
  --allowedTools "Bash"
```

**2. Write the plist** — `plists/com.macpilot.my-task.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.macpilot.my-task</string>
  <key>ProgramArguments</key>
  <array>
    <string>__MACPILOT_DIR__/agents/my-task.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>__MACPILOT_DIR__/logs/my-task.out</string>
  <key>StandardErrorPath</key>
  <string>__MACPILOT_DIR__/logs/my-task.err</string>
</dict>
</plist>
```

**3. Install:** `./install.sh`

To reuse one script across multiple projects, create additional plists with different `EnvironmentVariables` (e.g. `PROJECT_DIR`, `MACPILOT_AGENT_NAME`).

## Running manually

```sh
# Run with .env defaults
./agents/example.sh

# Override per-run
PROJECT_DIR=~/Developer/OtherApp TEST_PLAN=UnitTests ./agents/test-xcode-project.sh
```

Agents can be tested from inside a Claude Code session — the library clears nesting env vars automatically.

## Headless deployment

MacPilot works on a dedicated Mac Mini with auto-login and no GUI session:

- **Notifications** go through ntfy.sh — no GUI required
- **PATH** is set up automatically — Homebrew, Xcode tools, and `/usr/local/bin` are prepended so launchd jobs find everything
- **Log rotation** runs weekly (Sunday 3 AM) via `com.macpilot.rotate-logs.plist`, deleting logs and reports older than 30 days. Override with `MACPILOT_LOG_RETENTION_DAYS` in `.env`.
- **Self-improvement** runs weekly (Sunday 4 AM) — reads your goals from `config/goals.md` and recent logs, then proposes improvements on a git branch you review.

## Project structure

```
agents/           Shell scripts — one per agent type
plists/           launchd plists — one per project/schedule
lib/macpilot.sh   Shared library (find claude, load env, run, parse, log, notify)
lib/rotate-logs.sh  Log/report cleanup
config/.env       Your secrets and project paths (gitignored)
config/goals.md   Improvement goals for the meta-agent
logs/             Execution logs
reports/          Agent output (triage reports, fix plans, etc.)
```

## License

MIT
