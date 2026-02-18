import AppIntents

struct TransformTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Transform Text"
    static let description: IntentDescription = "Transform text using an instruction via AI."

    static let openAppWhenRun: Bool = false

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Instruction")
    var instruction: String

    static func buildPrompt(text: String, instruction: String) -> String {
        "Transform the following text according to the instruction.\n\nInstruction: \(instruction)\n\nText:\n\(text)"
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let prompt = Self.buildPrompt(text: text, instruction: instruction)
        let response = try await ClaudeCLI.shared.ask(prompt)
        return .result(value: response)
    }
}
