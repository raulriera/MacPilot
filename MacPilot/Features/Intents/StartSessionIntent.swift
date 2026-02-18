import AppIntents

/// Starts a new multi-turn conversation session with MacPilot.
///
/// Creates a persistent session that can be resumed later via
/// `ContinueSessionIntent`. Returns Claude's first response.
struct StartSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start MacPilot Session"
    static let description: IntentDescription = "Start a new conversation session with MacPilot"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Question")
    var question: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let (response, claudeSessionID) = try await ClaudeCLI.shared.startSession(question)

        // Derive a short name from the first few words of the question
        let name = String(question.prefix(40))

        try await MainActor.run {
            _ = try SessionManager.shared.createSession(
                claudeSessionID: claudeSessionID,
                name: name
            )
        }

        return .result(value: response)
    }
}
