import AppIntents
import AppKit

struct SummarizeClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize Clipboard"
    static let description: IntentDescription = "Summarize whatever text is currently on the clipboard."

    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let clipboardText = NSPasteboard.general.string(forType: .string),
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .result(value: "The clipboard is empty or contains no text.")
        }

        let prompt = "Summarize the following text concisely:\n\n\(clipboardText)"
        let response = try await ClaudeCLI.shared.ask(prompt)
        return .result(value: response)
    }
}
