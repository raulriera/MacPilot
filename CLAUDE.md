# MacPilot

A privacy-first personal AI assistant for macOS that runs 24/7 and integrates exclusively through Apple Shortcuts. Inspired by [OpenClaw](https://github.com/openclaw/openclaw), but simplified, Swift-native, and security-focused.

## Project Goals

- Run as a lightweight background process (menu bar app) on macOS
- Expose all functionality through Apple Shortcuts via App Intents
- Keep all data local — nothing leaves the machine except Claude CLI invocations
- Zero third-party dependencies — Apple frameworks only
- Provide an extensible tool system the AI can invoke on behalf of the user
- Be simple to install, configure, and extend

## Architecture

### Runtime Model

MacPilot is a **macOS menu bar app** built with SwiftUI using `MenuBarExtra`. It:

- Sets `LSUIElement = true` in Info.plist to hide from the Dock
- Registers as a login item via `SMAppService` so it starts on boot
- Runs 24/7 while the user is logged in
- Provides a menu bar icon for status, quick actions, and configuration

### Shortcuts Integration (Primary)

The **App Intents framework** is the primary interface. Each capability is exposed as an `AppIntent` that appears natively in Apple Shortcuts. Users build automations by composing these intents.

Key design rules for App Intents:
- Each intent should do one thing well
- Use `AppEntity` for dynamic types, `AppEnum` for fixed sets
- Intents should support background execution (no foregrounding unless necessary)
- Return structured results that Shortcuts can pipe to other actions

### Local HTTP Server (Secondary)

A lightweight local HTTP server built with Apple's **Network framework** (`NWListener` + `NWConnection`) listens on `http://127.0.0.1:<PORT>` as a secondary interface for:
- Advanced automations that exceed App Intents' parameter model
- Debugging and development (curl, Postman)
- Future cross-device communication
- Webhooks and callback-based workflows

No third-party server frameworks — raw HTTP parsing over `NWListener` using TCP.

### AI Integration — Claude CLI

MacPilot does **not** use API keys or direct HTTP calls to Anthropic. Instead, it invokes the user's locally installed **Claude Code CLI** (`claude`) via `Process` (Foundation).

#### How it works

```swift
// Example: invoking Claude from Swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude") // or resolved via `which claude`
process.arguments = [
    "-p", prompt,              // non-interactive print mode
    "--output-format", "json", // structured JSON response
    "--max-turns", "3",        // limit agentic turns
    "--no-session-persistence" // don't persist in Claude's session list
]
```

#### Key CLI flags used

| Flag | Purpose |
|---|---|
| `-p "prompt"` | Non-interactive mode — send prompt, get response, exit |
| `--output-format json` | Structured JSON output for parsing |
| `--append-system-prompt` | Inject MacPilot context without replacing Claude's defaults |
| `--max-turns N` | Limit agentic turns to control cost and runtime |
| `--max-budget-usd N` | Hard spending cap per invocation |
| `--model sonnet` | Select model (sonnet for speed, opus for quality) |
| `--tools "Read,Bash"` | Restrict which tools Claude can use per invocation |
| `--allowedTools` | Pre-approve specific tool patterns to avoid permission prompts |
| `--no-session-persistence` | Keep MacPilot sessions out of Claude's session list |
| `-c` / `--resume` | Continue or resume a conversation for multi-turn flows |
| `--json-schema` | Get validated structured output matching a schema |

#### Benefits of CLI approach

- **No API key management** — uses the user's existing Claude authentication
- **No billing complexity** — usage goes through the user's existing subscription
- **Always up-to-date** — picks up Claude Code updates automatically
- **Full agentic capabilities** — Claude can use its built-in tools (Read, Edit, Bash, etc.)
- **Session continuity** — can resume conversations via `--resume` for multi-turn interactions
- **Structured output** — `--json-schema` gives validated JSON matching a schema

#### MCP Integration (Tool System)

MacPilot's tool system uses [MCP (Model Context Protocol)](https://modelcontextprotocol.io) via the `--mcp-config` CLI flag. MacPilot bundles a lightweight command-line tool (`MacPilotMCP`) that speaks the MCP stdio protocol (JSON-RPC 2.0 over stdin/stdout). When MacPilot invokes Claude CLI with `--mcp-config`, Claude spawns the MCP server, discovers its tools, and calls them as needed — all within one CLI invocation.

The MCP stdio protocol requires only 3 methods: `initialize`, `tools/list`, `tools/call`. Implemented from scratch (~200 lines) to maintain the zero-dependency constraint.

| Flag | Purpose |
|---|---|
| `--mcp-config <path>` | Points Claude CLI to the MCP server configuration |
| `--allowedTools "mcp__macpilot__*"` | Pre-approves MacPilot MCP tools to avoid interactive prompts |

#### Considerations

- Requires Claude Code to be installed and authenticated
- Each invocation spawns a subprocess — keep prompts focused to minimize latency
- Use `--max-turns` and `--max-budget-usd` to prevent runaway invocations
- Parse the JSON output array for `assistant` messages and tool results

### Data Storage

- **SwiftData** for conversation history, tool configs, and session state
- **Keychain** via Security framework for any sensitive configuration
- **FileManager** with Data Protection for local files
- No iCloud sync by default — local-only

## Core Components

### Tool System

Tools are Swift types conforming to a `Tool` protocol:

```swift
protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }
    func execute(arguments: [String: JSONValue]) async throws -> ToolResult
}
```

The AI agent can invoke tools during a conversation via MCP (Model Context Protocol). Built-in tools include:
- **Clipboard** — read/write `NSPasteboard`
- **Notification** — send macOS notifications via `UserNotifications`
- **Web** — fetch URLs via `URLSession`, parse content

Future tools (higher security risk, separate milestone):
- **Shell** — run whitelisted commands (with user approval)
- **File** — read/write files in sandboxed locations

Capabilities intentionally excluded — use Apple Shortcuts instead:
- **Calendar/Reminders** — Shortcuts provides "Find Calendar Events" and "Find Reminders" natively
- **Cron/Scheduling** — Shortcuts Automations handle time-based, location-based, and event-based triggers

### Session Management

- Conversations are isolated by session
- Sessions can be named and resumed (leveraging Claude CLI's `--resume` flag)
- MacPilot tracks session IDs locally in SwiftData, maps them to Claude CLI session IDs
- Context window management is handled by Claude CLI natively
- Sessions are stored locally in SwiftData

## User Experience

MacPilot has no chat window. You never "open the app." You interact with it through **Shortcuts you build yourself** — triggered by Siri, keyboard shortcuts, the menu bar, or time-based automations.

### Two Layers: App Shortcuts vs. App Intents

MacPilot exposes functionality through two complementary layers:

**App Shortcuts** (via `AppShortcutsProvider`) are **pre-built, ready-to-use shortcuts that ship with the app**. They:
- Appear automatically in the Shortcuts app under "MacPilot" — zero setup
- Work with Siri immediately via predefined phrases
- Show up in Spotlight search
- Require no user configuration

**App Intents** are the raw building blocks. They show up in the Shortcuts app as individual actions users can drag into custom workflows. Power users compose these alongside Apple's built-in actions to create their own automations.

#### Built-in App Shortcuts (work on day one)

These are available the moment MacPilot is installed, no configuration needed:

| Shortcut | Siri phrase | What it does |
|---|---|---|
| **Ask MacPilot** | "Ask MacPilot a question" | Prompts for text, returns Claude's answer |
| **Summarize Clipboard** | "MacPilot explain this" | Summarizes whatever is on the clipboard |
| **Transform Text** | "MacPilot rewrite this" | Takes clipboard + instruction, returns transformed text |
| **Start Conversation** | "Start a MacPilot session" | Begins a multi-turn chat session |

#### How built-in shortcuts are defined

```swift
// 1. The App Intent (building block)
struct AskMacPilotIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask MacPilot"

    @Parameter(title: "Question")
    var question: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await ClaudeCLI.ask(question)
        return .result(value: response)
    }
}

// 2. The App Shortcut (pre-built, ships with the app)
struct MacPilotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskMacPilotIntent(),
            phrases: [
                "Ask \(.applicationName) a question",
                "Hey \(.applicationName)",
                "Ask \(.applicationName) \(\.$question)"
            ],
            shortTitle: "Ask MacPilot",
            systemImageName: "brain"
        )

        AppShortcut(
            intent: SummarizeClipboardIntent(),
            phrases: [
                "Summarize with \(.applicationName)",
                "\(.applicationName) explain this"
            ],
            shortTitle: "Summarize Clipboard",
            systemImageName: "doc.text"
        )
    }
}
```

#### App Intents Catalog (building blocks for custom Shortcuts)

These are the individual intents power users can compose into custom workflows:

| Intent | Input | Output | Example trigger |
|---|---|---|---|
| **Ask MacPilot** | A text prompt (+ optional context) | Text response | Siri, keyboard shortcut |
| **Transform Text** | Text + instruction | Transformed text | Quick Action, keyboard shortcut |
| **Start Session** | A text prompt | Session ID + first response | Shortcut button |
| **Continue Session** | Session ID + text prompt | Text response | Chained in a Shortcut loop |
| **Summarize File** | A file (PDF, text, code) | Text summary | Share Sheet, Quick Action |
| **Run Saved Task** | Task name | Task output | Automation, menu bar |

Each intent is a composable primitive — the user wires them together in Shortcuts however they want. MacPilot does not prescribe workflows.

### Example Workflows

#### Quick question via Siri

> "Hey Siri, ask MacPilot what does this file do"

1. Siri matches the phrase to the **Ask MacPilot** App Shortcut
2. The intent grabs the current clipboard as context
3. MacPilot runs: `claude -p "Explain what this code does: <clipboard>" --output-format json --max-turns 1 --model sonnet`
4. Parses the JSON response, extracts the assistant message
5. Returns it to Shortcuts, which speaks it back or shows a notification

**Result:** "This is a SwiftData model that tracks user sessions. It has three properties..."

#### Morning briefing on a schedule

A Shortcuts Automation runs every day at 8:30 AM:

1. **Get Calendar Events** (today) — built-in Shortcuts action
2. **Get Reminders** (due today) — built-in Shortcuts action
3. **Ask MacPilot** — prompt: *"Here's my calendar and reminders for today. Give me a 3-sentence briefing with priorities."*
4. **Show Notification** — displays MacPilot's response

**Result at 8:30 AM:** "You have 4 meetings today, the heaviest block is 1-3pm. Your top priority is the PR review for the auth module (due today). You have a 2-hour gap from 10-12 — good time for deep work."

#### Keyboard shortcut to refactor code

`Cmd+Shift+R` is bound to a Shortcut called "MacPilot Refactor":

1. **Get Selected Text** from the frontmost app
2. **Transform Text** — instruction: *"Refactor this to use async/await instead of completion handlers"*
3. MacPilot calls Claude with `--json-schema` to get back just the refactored code
4. **Copy to Clipboard**
5. **Show Notification** — "Refactored code copied to clipboard"

**Result:** `Cmd+V` to paste the refactored version.

#### Multi-turn conversation via Shortcuts

A Shortcut called "Chat with MacPilot" using a Repeat loop:

1. Prompts you: *"What do you need help with?"*
2. You type: *"My SwiftData migration is crashing on launch"*
3. **Start Session** — sends the prompt, returns a session ID + response
4. Shows Claude's response, prompts you: *"Reply (or leave empty to end)"*
5. You type: *"The error is: Fatal error — failed to find a currently active container"*
6. **Continue Session** — resumes with `--resume <session-id>`, sends your reply
7. Shows Claude's fix, prompts again
8. You leave the field empty — the loop ends

All of this happens in Shortcuts dialogs — no app window ever opens.

#### File processing via Share Sheet

Right-click a PDF on the desktop, choose **"Summarize with MacPilot"** from the Share menu:

1. The Quick Action receives the file
2. Extracts text from the PDF (built-in Shortcuts action)
3. **Summarize File** — prompt: *"Summarize this document in bullet points"*
4. Shows the summary in a Quick Look popup

#### Proactive automation — email triage

A Shortcuts Automation triggers when you receive an email from a specific sender:

1. Gets the email subject and body
2. **Ask MacPilot** — prompt: *"Is this email urgent? Reply with JSON: {urgent: bool, action: string}"* (uses `--json-schema`)
3. If `urgent == true`: sends a critical notification with the suggested action
4. If `urgent == false`: does nothing

### Design Principles

The user is always in control of the workflow. MacPilot provides AI primitives (ask, transform, summarize, converse). The user composes them in Shortcuts alongside Apple's built-in actions (get calendar events, get clipboard, show notification, send message, etc.). This means every workflow is transparent, editable, and deletable — no hidden behavior.

**Don't re-wrap macOS** — if Apple already exposes a capability as a Shortcuts action or system feature, don't duplicate it. MacPilot adds AI primitives. Users compose them with Apple's built-in actions.

## Privacy & Security

### Principles

1. **Local-first**: All data stays on the user's machine
2. **No API keys**: Authentication delegated to Claude CLI's existing auth
3. **Minimal permissions**: Only request entitlements needed by enabled tools
4. **Encrypted at rest**: SwiftData store with file-level protection
5. **No telemetry**: Zero analytics, tracking, or data collection
6. **Explicit consent**: Every tool action that touches system resources requires user approval
7. **Auditable**: All AI-initiated actions are logged locally

### Threat Model

- No API keys to leak — Claude CLI handles its own authentication
- The local HTTP server binds to `127.0.0.1` only (not `0.0.0.0`)
- Shell command execution is restricted to a configurable allowlist
- File access is sandboxed to user-approved directories
- Network requests from tools go through `URLSession` with configurable restrictions
- Claude CLI invocations use `--max-turns` and `--max-budget-usd` to prevent abuse

### Distribution

- If distributed via Mac App Store: full sandbox, limited tools
- If distributed independently: hardened runtime, notarized, broader tool access
- Code signing is mandatory in both cases

## Tech Stack

- **Language**: Swift 6 (strict concurrency)
- **UI**: SwiftUI (`MenuBarExtra`, Settings window)
- **Local Server**: `Network` framework (`NWListener`, `NWConnection`)
- **Storage**: SwiftData
- **Secrets**: Security framework (Keychain)
- **AI**: Claude Code CLI via `Process` (Foundation)
- **Intents**: App Intents framework
- **Notifications**: `UserNotifications`
- **Speech** (future): `AVSpeechSynthesizer`, `SFSpeechRecognizer`
- **Dependencies**: None — Apple frameworks only
- **Minimum target**: macOS 15 (Sequoia) — for latest App Intents and SwiftData features

## Project Structure (Planned)

```
MacPilot/
  MacPilotApp.swift          # App entry point, MenuBarExtra
  Features/
    Assistant/               # Claude CLI wrapper, prompt building, response parsing
    Tools/                   # Tool protocol + built-in tools + execution logging
    Intents/                 # App Intents definitions
    Server/                  # NWListener-based local HTTP server
    Notifications/           # UNUserNotificationCenter wrapper
    Storage/                 # SwiftData models, Keychain helpers
  Resources/
    Assets.xcassets
  MacPilot.entitlements
  Info.plist
MacPilotMCP/                 # MCP server binary (stdio JSON-RPC 2.0)
  main.swift
  JSONRPCServer.swift
  MCPServer.swift
  ToolBridge.swift
```

## Development Guidelines

- Use Swift 6 strict concurrency (`Sendable`, actors, structured concurrency)
- Zero third-party dependencies — if it's not in an Apple SDK, don't use it
- Prefer value types (structs, enums) over classes where possible
- All async work uses structured concurrency (`async/await`, `TaskGroup`)
- No force unwraps (`!`) in production code
- All tool executions are logged with timestamp, tool name, arguments, and result
- Tests: Swift Testing for unit tests, UI tests for the menu bar interface
- Follow Apple's Human Interface Guidelines for the menu bar app

## References

- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference)
- [App Intents Documentation](https://developer.apple.com/documentation/appintents)
- [WWDC25 — Get to know App Intents](https://developer.apple.com/videos/play/wwdc2025/244/)
- [WWDC25 — Explore new advances in App Intents](https://developer.apple.com/videos/play/wwdc2025/275/)
- [Network Framework — NWListener](https://developer.apple.com/documentation/network/nwlistener)
- [Building menu bar apps with SwiftUI](https://developer.apple.com/documentation/SwiftUI/Building-and-customizing-the-menu-bar-with-SwiftUI)
- [SMAppService (login items)](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [OpenClaw (inspiration)](https://github.com/openclaw/openclaw)
