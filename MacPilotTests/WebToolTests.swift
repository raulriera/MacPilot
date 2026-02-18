import Testing
@testable import MacPilot

@Suite("WebTool")
struct WebToolTests {
    let tool = WebTool()

    @Test("Invalid URL returns error")
    func invalidURL() async throws {
        let result = try await tool.execute(arguments: [
            "url": .string("")
        ])

        #expect(result.isError)
        #expect(result.content.contains("Invalid URL"))
    }

    @Test("Non-HTTP scheme returns error")
    func nonHTTPScheme() async throws {
        let result = try await tool.execute(arguments: [
            "url": .string("ftp://example.com/file.txt")
        ])

        #expect(result.isError)
        #expect(result.content.contains("http"))
    }

    @Test("File scheme returns error")
    func fileScheme() async throws {
        let result = try await tool.execute(arguments: [
            "url": .string("file:///etc/passwd")
        ])

        #expect(result.isError)
        #expect(result.content.contains("http"))
    }

    @Test("Missing url parameter returns error")
    func missingURL() async throws {
        let result = try await tool.execute(arguments: [:])

        #expect(result.isError)
        #expect(result.content.contains("url"))
    }

    @Test("URL without scheme returns error")
    func noScheme() async throws {
        let result = try await tool.execute(arguments: [
            "url": .string("example.com")
        ])

        #expect(result.isError)
    }

    @Test("Max response length is 50,000")
    func maxResponseLength() {
        #expect(WebTool.maxResponseLength == 50_000)
    }

    @Test("Timeout is 30 seconds")
    func timeout() {
        #expect(WebTool.timeoutInterval == 30)
    }
}
