import AppIntents

struct MacPilotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskMacPilotIntent(),
            phrases: [
                "Ask \(.applicationName) a question",
                "Hey \(.applicationName)"
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

        AppShortcut(
            intent: StartSessionIntent(),
            phrases: [
                "Start a \(.applicationName) session",
                "New \(.applicationName) conversation"
            ],
            shortTitle: "Start Session",
            systemImageName: "bubble.left.and.bubble.right"
        )

        AppShortcut(
            intent: ContinueSessionIntent(),
            phrases: [
                "Continue \(.applicationName) session",
                "Reply to \(.applicationName)"
            ],
            shortTitle: "Continue Session",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
    }
}
