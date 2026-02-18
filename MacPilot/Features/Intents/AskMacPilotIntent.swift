import AppIntents

struct AskMacPilotIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask MacPilot"
    static let description: IntentDescription = "Ask MacPilot a question and get an AI-powered answer."

    static let openAppWhenRun: Bool = false

    @Parameter(title: "Question")
    var question: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response = try await ClaudeCLI.shared.ask(question)
        return .result(value: response)
    }
}
