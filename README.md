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

Open Claude Code in the MacPilot directory and describe what you want:

> "Create an agent that summarizes the git log from the past week and runs every Monday at 9 AM"

Claude has the full project context via CLAUDE.md and will create the script, plist, and wire everything up. Run `./install.sh` to activate it.

## Running manually

```sh
# Run with .env defaults
./agents/example.sh

# Override per-run
PROJECT_DIR=~/Developer/OtherApp TEST_PLAN=UnitTests ./agents/test-xcode-project.sh
```

Agents can be tested from inside a Claude Code session — the library clears nesting env vars automatically.

## Headless deployment

MacPilot works with no GUI session:

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
