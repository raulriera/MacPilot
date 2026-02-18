import AppIntents

struct SummarizeFileIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize File"
    static let description: IntentDescription = "Summarize the contents of a file using AI."

    static let openAppWhenRun: Bool = false

    static let maxContentLength = 100_000

    @Parameter(title: "File")
    var file: IntentFile

    static func prepareContent(from data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if text.count > maxContentLength {
            return String(text.prefix(maxContentLength)) + "\n\n[Truncated — file exceeds \(maxContentLength) characters]"
        }

        return text
    }

    static func buildPrompt(filename: String?, content: String) -> String {
        "Summarize the following file concisely in bullet points.\n\nFilename: \(filename ?? "unknown")\n\n\(content)"
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let content = Self.prepareContent(from: file.data) else {
            return .result(value: "The file is empty or contains no readable text.")
        }

        let prompt = Self.buildPrompt(filename: file.filename, content: content)
        let response = try await ClaudeCLI.shared.ask(prompt)
        return .result(value: response)
    }
}
