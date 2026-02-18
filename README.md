# MacPilot

A privacy-first personal AI assistant for macOS. Runs as a menu bar app, exposes everything through Apple Shortcuts, and talks to Claude via the local CLI. No API keys, no cloud sync, no third-party dependencies.

## Principles

- **Local-first** — all data stays on your machine. Nothing leaves except Claude CLI invocations.
- **Shortcuts-native** — every capability is an App Intent. You build your own workflows in Shortcuts.
- **Don't re-wrap macOS** — if Apple already exposes it (calendar, reminders, scheduling), we don't duplicate it. MacPilot adds AI primitives. You compose them with Apple's built-in actions.
- **Zero dependencies** — Apple frameworks only. No SPM packages, no CocoaPods, no vendored code.
- **No telemetry** — zero analytics, tracking, or data collection.

## Prerequisites

| Requirement | Why |
|---|---|
| **macOS 26** (Tahoe) or later | App Intents and SwiftData features require it |
| **Xcode 26** or later | Swift 6 strict concurrency, macOS 26 SDK |
| **[Claude Code CLI](https://claude.ai/download)** | MacPilot calls `claude` as a subprocess — no API keys needed |
| **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** | Generates the `.xcodeproj` from `project.yml` |

### Install prerequisites

```bash
# Claude Code CLI — follow https://claude.ai/download, then:
claude  # run once to authenticate

# XcodeGen
brew install xcodegen
```

## Installation

### 1. Clone and generate the project

```bash
git clone git@github.com:raulriera/MacPilot.git
cd MacPilot
xcodegen generate
```

This creates `MacPilot.xcodeproj` from `project.yml`.

### 2. Build

Open in Xcode:

```bash
open MacPilot.xcodeproj
```

Or build from the command line:

```bash
xcodebuild build -project MacPilot.xcodeproj -scheme MacPilot -destination "platform=macOS"
```

### 3. Run

Press `Cmd+R` in Xcode, or launch the built app. MacPilot appears as a **brain icon in the menu bar** — there is no Dock icon and no main window.

From the menu bar icon you can:
- Toggle **Launch at Login**
- Quit the app

### 4. Grant permissions

On first use, macOS will prompt for **notification permissions**. Accept to enable the notification tool and the Send Notification intent.

## Using MacPilot

MacPilot has no chat window. You interact with it entirely through **Apple Shortcuts**.

### Built-in Shortcuts (work immediately)

Open **Shortcuts.app** and look under **MacPilot** in the App Shortcuts section. These are ready to use with zero configuration:

| Shortcut | Siri phrase | What it does |
|---|---|---|
| **Ask MacPilot** | "Ask MacPilot a question" | Send a question, get a text answer |
| **Ask with Tools** | "Ask MacPilot to do something" | Same, but Claude can use clipboard, web, notifications, and shell |
| **Summarize Clipboard** | "MacPilot explain this" | Summarizes whatever is on your clipboard |
| **Transform Text** | "MacPilot rewrite this" | Takes clipboard + an instruction, returns transformed text |
| **Summarize File** | "Summarize file with MacPilot" | Summarizes a file's contents |
| **Start Session** | "Start a MacPilot session" | Begins a multi-turn conversation |
| **Continue Session** | "Continue MacPilot session" | Continues an existing session |
| **Send Notification** | "Send a MacPilot notification" | Sends a local notification |

### Building custom Shortcuts

The real power is composing MacPilot intents with Apple's built-in actions. Examples:

**Morning briefing** (Shortcuts Automation, daily at 8:30 AM):
1. Get Calendar Events (today)
2. Get Reminders (due today)
3. Ask MacPilot → "Here's my calendar and reminders. Give me a 3-sentence briefing."
4. Show Notification

**Refactor code** (bound to `Cmd+Shift+R`):
1. Get Selected Text
2. Transform Text → "Refactor this to use async/await"
3. Copy to Clipboard
4. Show Notification → "Refactored code on clipboard"

**GitHub triage** (single shortcut):
1. Ask with Tools → "Check my top GitHub issues on owner/repo and prioritize them"
2. Claude runs `gh issue list`, reads the results, and returns a prioritized summary

**Project summary** (bound to a keyboard shortcut):
1. Ask with Tools → "Run git log on ~/Developer/MyApp and summarize what changed this week"
2. Claude runs `git log --since='1 week ago'`, analyzes the commits, and returns a summary

**Disk check** (Shortcuts Automation, daily at 9 AM):
1. Ask with Tools → "Check my disk space and notify me if any volume is below 20% free"
2. Claude runs `df -h`, evaluates the output, and sends a notification if needed

**AI with tools** (single shortcut):
1. Ask with Tools → "Read my clipboard, summarize it, and send the summary as a notification"
2. Claude reads the clipboard, processes it, and sends a notification — all in one step

### Ask MacPilot vs Ask with Tools

| | Ask MacPilot | Ask with Tools |
|---|---|---|
| Speed | Fast (1 turn) | Slower (up to 5 turns) |
| Tools | None | Clipboard, Web, Notifications, Shell |
| Use when | Quick Q&A | You need Claude to *do* something |

## MCP Tools

When using **Ask with Tools**, Claude can call these tools during the conversation:

| Tool | What it does |
|---|---|
| `clipboard` | Read or write the macOS clipboard |
| `web` | Fetch a URL and return its text content |
| `notification` | Send a macOS notification |
| `shell` | Execute a shell command and return its output |

Tools are exposed via [MCP (Model Context Protocol)](https://modelcontextprotocol.io). MacPilot bundles a lightweight MCP server (`MacPilotMCP`) that Claude CLI spawns automatically.

## Quick Test

After building and running MacPilot (`Cmd+R`), its App Shortcuts register automatically. You can run them from Terminal:

```bash
# List MacPilot shortcuts
shortcuts list | grep -i macpilot

# Run one (it will prompt for input)
shortcuts run "Ask MacPilot"
```

Or open **Shortcuts.app**, find **MacPilot** in the sidebar, and tap any shortcut.

### Unit tests

```bash
xcodebuild test -project MacPilot.xcodeproj -scheme MacPilot -destination "platform=macOS"
```

## Project Structure

```
MacPilot/
  MacPilotApp.swift              # App entry point, MenuBarExtra
  Features/
    Assistant/                   # Claude CLI wrapper, prompt building, MCP config
    Tools/                       # Tool protocol, implementations, execution logging
    Intents/                     # App Intents + App Shortcuts
    Notifications/               # UNUserNotificationCenter wrapper
    Storage/                     # SwiftData models (Session, ToolExecutionLog)
MacPilotMCP/                     # MCP server binary (JSON-RPC 2.0 over stdio)
MacPilotTests/                   # Swift Testing unit tests
project.yml                      # XcodeGen project definition
```

## Tech Stack

Swift 6 (strict concurrency) · SwiftUI · SwiftData · App Intents · UserNotifications · URLSession · Foundation `Process` — Apple frameworks only.

## License

TBD
