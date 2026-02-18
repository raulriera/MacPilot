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

        AppShortcut(
            intent: TransformTextIntent(),
            phrases: [
                "\(.applicationName) rewrite this",
                "Transform with \(.applicationName)"
            ],
            shortTitle: "Transform Text",
            systemImageName: "pencil.and.outline"
        )

        AppShortcut(
            intent: SummarizeFileIntent(),
            phrases: [
                "Summarize file with \(.applicationName)",
                "\(.applicationName) summarize this file"
            ],
            shortTitle: "Summarize File",
            systemImageName: "doc.text.magnifyingglass"
        )

        AppShortcut(
            intent: SendNotificationIntent(),
            phrases: [
                "Send a \(.applicationName) notification",
                "\(.applicationName) notify me"
            ],
            shortTitle: "Send Notification",
            systemImageName: "bell"
        )
    }
}
