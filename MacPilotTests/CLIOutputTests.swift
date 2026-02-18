import Testing
import Foundation
@testable import MacPilot

@Suite("CLIOutput")
struct CLIOutputTests {

    // MARK: - parseResult

    @Test("parseResult extracts result from valid JSON")
    func parseResultValid() throws {
        let json = """
        {"type": "result", "result": "Hello, world!"}
        """
        let data = Data(json.utf8)
        let result = try CLIOutput.parseResult(from: data)
        #expect(result == "Hello, world!")
    }

    @Test("parseResult ignores session_id field")
    func parseResultIgnoresSessionID() throws {
        let json = """
        {"type": "result", "result": "Answer", "session_id": "sess-123"}
        """
        let data = Data(json.utf8)
        let result = try CLIOutput.parseResult(from: data)
        #expect(result == "Answer")
    }

    @Test("parseResult throws noResultMessage when type is not result")
    func parseResultWrongType() {
        let json = """
        {"type": "error", "result": "oops"}
        """
        let data = Data(json.utf8)
        #expect(throws: ClaudeCLIError.self) {
            try CLIOutput.parseResult(from: data)
        }
    }

    @Test("parseResult throws noResultMessage when result is null")
    func parseResultNullResult() {
        let json = """
        {"type": "result", "result": null}
        """
        let data = Data(json.utf8)
        #expect(throws: ClaudeCLIError.self) {
            try CLIOutput.parseResult(from: data)
        }
    }

    @Test("parseResult throws jsonDecodingFailed for invalid JSON")
    func parseResultInvalidJSON() {
        let data = Data("not json".utf8)
        #expect(throws: ClaudeCLIError.self) {
            try CLIOutput.parseResult(from: data)
        }
    }

    // MARK: - parseSessionResult

    @Test("parseSessionResult extracts both result and session ID")
    func parseSessionResultValid() throws {
        let json = """
        {"type": "result", "result": "Started!", "session_id": "sess-abc-123"}
        """
        let data = Data(json.utf8)
        let (result, sessionID) = try CLIOutput.parseSessionResult(from: data)
        #expect(result == "Started!")
        #expect(sessionID == "sess-abc-123")
    }

    @Test("parseSessionResult throws noSessionID when session_id is missing")
    func parseSessionResultMissingSessionID() {
        let json = """
        {"type": "result", "result": "Hello"}
        """
        let data = Data(json.utf8)
        #expect(throws: ClaudeCLIError.self) {
            try CLIOutput.parseSessionResult(from: data)
        }
    }

    @Test("parseSessionResult throws noResultMessage when result is missing")
    func parseSessionResultMissingResult() {
        let json = """
        {"type": "result", "session_id": "sess-123"}
        """
        let data = Data(json.utf8)
        #expect(throws: ClaudeCLIError.self) {
            try CLIOutput.parseSessionResult(from: data)
        }
    }

    @Test("parseSessionResult throws for wrong type")
    func parseSessionResultWrongType() {
        let json = """
        {"type": "system", "result": "Hello", "session_id": "sess-123"}
        """
        let data = Data(json.utf8)
        #expect(throws: ClaudeCLIError.self) {
            try CLIOutput.parseSessionResult(from: data)
        }
    }

    // MARK: - CLIMessage decoding

    @Test("CLIMessage decodes all fields correctly")
    func cliMessageFullDecode() throws {
        let json = """
        {"type": "result", "subtype": "success", "result": "Done", "session_id": "s-1"}
        """
        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(CLIMessage.self, from: data)
        #expect(message.type == "result")
        #expect(message.subtype == "success")
        #expect(message.result == "Done")
        #expect(message.sessionID == "s-1")
    }

    @Test("CLIMessage handles missing optional fields")
    func cliMessageMinimalDecode() throws {
        let json = """
        {"type": "result"}
        """
        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(CLIMessage.self, from: data)
        #expect(message.type == "result")
        #expect(message.subtype == nil)
        #expect(message.result == nil)
        #expect(message.sessionID == nil)
    }
}
