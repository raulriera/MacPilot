import AppIntents

/// App Intent that sends a prompt to Claude with MacPilot tools enabled.
///
/// Unlike `AskMacPilotIntent`, this intent enables MCP tools so Claude can
/// read the clipboard, fetch URLs, send notifications, etc. during the conversation.
/// Slower than plain Q&A due to additional turns and subprocess overhead.
struct AskWithToolsIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask MacPilot with Tools"
    static let description: IntentDescription = "Ask MacPilot a question with access to system tools (clipboard, web, notifications, shell)."

    static let openAppWhenRun: Bool = false

    @Parameter(title: "Question")
    var question: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await ClaudeCLI.shared.askWithTools(question)
        return .result(value: response)
    }
}
