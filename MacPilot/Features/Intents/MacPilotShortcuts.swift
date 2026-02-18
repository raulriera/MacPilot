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
    }
}
