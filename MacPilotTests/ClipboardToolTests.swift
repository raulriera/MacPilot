import Testing
import AppKit
@testable import MacPilot

@Suite("ClipboardTool", .serialized)
struct ClipboardToolTests {
    let tool = ClipboardTool()

    @Test("Read returns clipboard content")
    func readClipboard() async throws {
        // Set a known value on the clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("test content", forType: .string)

        let result = try await tool.execute(arguments: [
            "action": .string("read")
        ])

        #expect(!result.isError)
        #expect(result.content == "test content")
    }

    @Test("Read returns empty message when clipboard is empty")
    func readEmptyClipboard() async throws {
        NSPasteboard.general.clearContents()

        let result = try await tool.execute(arguments: [
            "action": .string("read")
        ])

        #expect(!result.isError)
        #expect(result.content == "Clipboard is empty.")
    }

    @Test("Write sets clipboard content")
    func writeClipboard() async throws {
        let result = try await tool.execute(arguments: [
            "action": .string("write"),
            "content": .string("new content")
        ])

        #expect(!result.isError)
        #expect(result.content == "Clipboard updated.")

        // Verify the clipboard was updated
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        #expect(clipboardContent == "new content")
    }

    @Test("Write without content returns error")
    func writeWithoutContent() async throws {
        let result = try await tool.execute(arguments: [
            "action": .string("write")
        ])

        #expect(result.isError)
        #expect(result.content.contains("content"))
    }

    @Test("Missing action returns error")
    func missingAction() async throws {
        let result = try await tool.execute(arguments: [:])

        #expect(result.isError)
        #expect(result.content.contains("action"))
    }

    @Test("Unknown action returns error")
    func unknownAction() async throws {
        let result = try await tool.execute(arguments: [
            "action": .string("delete")
        ])

        #expect(result.isError)
        #expect(result.content.contains("Unknown action"))
    }

    @Test("Write then read round-trip")
    func writeReadRoundTrip() async throws {
        let testValue = "round-trip test \(UUID().uuidString)"

        _ = try await tool.execute(arguments: [
            "action": .string("write"),
            "content": .string(testValue)
        ])

        let result = try await tool.execute(arguments: [
            "action": .string("read")
        ])

        #expect(!result.isError)
        #expect(result.content == testValue)
    }
}
