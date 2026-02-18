import Testing
import Foundation
@testable import MacPilot

@Suite("SummarizeFileIntent")
struct SummarizeFileIntentTests {

    // MARK: - Metadata

    @Test("Title is Summarize File")
    func title() {
        #expect(SummarizeFileIntent.title == "Summarize File")
    }

    @Test("Does not open app when run")
    func openAppWhenRun() {
        #expect(SummarizeFileIntent.openAppWhenRun == false)
    }

    // MARK: - Content preparation

    @Test("Prepares valid UTF-8 text")
    func preparesValidText() {
        let data = "Hello, world!".data(using: .utf8)!
        let result = SummarizeFileIntent.prepareContent(from: data)

        #expect(result == "Hello, world!")
    }

    @Test("Returns nil for empty data")
    func returnsNilForEmptyData() {
        let data = Data()
        let result = SummarizeFileIntent.prepareContent(from: data)

        #expect(result == nil)
    }

    @Test("Returns nil for whitespace-only content")
    func returnsNilForWhitespace() {
        let data = "   \n\t  \n  ".data(using: .utf8)!
        let result = SummarizeFileIntent.prepareContent(from: data)

        #expect(result == nil)
    }

    @Test("Truncates content exceeding max length")
    func truncatesLongContent() {
        let longText = String(repeating: "a", count: SummarizeFileIntent.maxContentLength + 500)
        let data = longText.data(using: .utf8)!
        let result = SummarizeFileIntent.prepareContent(from: data)!

        #expect(result.count < longText.count)
        #expect(result.contains("[Truncated"))
        #expect(result.hasPrefix(String(repeating: "a", count: 100)))
    }

    @Test("Does not truncate content within max length")
    func doesNotTruncateShortContent() {
        let text = String(repeating: "b", count: 1000)
        let data = text.data(using: .utf8)!
        let result = SummarizeFileIntent.prepareContent(from: data)!

        #expect(result == text)
        #expect(!result.contains("[Truncated"))
    }

    @Test("Content at exact max length is not truncated")
    func exactMaxLengthNotTruncated() {
        let text = String(repeating: "c", count: SummarizeFileIntent.maxContentLength)
        let data = text.data(using: .utf8)!
        let result = SummarizeFileIntent.prepareContent(from: data)!

        #expect(result == text)
        #expect(!result.contains("[Truncated"))
    }

    // MARK: - Prompt construction

    @Test("Prompt includes filename and content")
    func promptIncludesFilenameAndContent() {
        let prompt = SummarizeFileIntent.buildPrompt(
            filename: "readme.md",
            content: "This is the content."
        )

        #expect(prompt.contains("Filename: readme.md"))
        #expect(prompt.contains("This is the content."))
        #expect(prompt.contains("bullet points"))
    }

    @Test("Prompt uses 'unknown' for nil filename")
    func promptUsesUnknownForNilFilename() {
        let prompt = SummarizeFileIntent.buildPrompt(
            filename: nil,
            content: "Some content"
        )

        #expect(prompt.contains("Filename: unknown"))
    }
}
