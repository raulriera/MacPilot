```
  __  __            ____  _ _       _
 |  \/  | __ _  ___|  _ \(_) | ___ | |_
 | |\/| |/ _` |/ __| |_) | | |/ _ \| __|
 | |  | | (_| | (__|  __/| | | (_) | |_
 |_|  |_|\__,_|\___|_|   |_|_|\___/ \__|
```

Scheduled autonomous Claude agents for macOS. Shell scripts + launchd, nothing else.

Each agent is a `.sh` file with a prompt and a `.plist` that tells macOS when to run it. Agents produce local artifacts — log files, reports, git branches — and send you a push notification when done. You review the results and decide what to publish. It even improves itself — a meta-agent reads your goals and recent logs, then proposes changes on a branch for you to review.

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

You'll see a list of available agents — pick the ones you want by number, or type `a` to install all of them. To skip the prompt (useful for automation), pass `--all`:

```sh
./install.sh --all
```

To remove agents, run `./uninstall.sh` — same interactive menu, same `--all` flag.

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
PROJECT_DIR=~/Developer/OtherApp ./agents/test-xcode-project.sh
```

Agents can be tested from inside a Claude Code session — the library clears nesting env vars automatically.

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
