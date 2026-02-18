import Foundation
import Testing
@testable import MacPilot

@Suite("JSONRPCServer")
struct JSONRPCServerTests {

    // MARK: - Request Parsing

    @Test("Parse valid request with all fields")
    func parseValidRequest() {
        let json = """
        {"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}
        """
        let data = json.data(using: .utf8)!
        let request = JSONRPCRequest.parse(from: data)

        #expect(request != nil)
        #expect(request?.id == 1)
        #expect(request?.method == "tools/list")
    }

    @Test("Parse notification (no id)")
    func parseNotification() {
        let json = """
        {"jsonrpc":"2.0","method":"notifications/initialized"}
        """
        let data = json.data(using: .utf8)!
        let request = JSONRPCRequest.parse(from: data)

        #expect(request != nil)
        #expect(request?.id == nil)
        #expect(request?.method == "notifications/initialized")
    }

    @Test("Parse request with params")
    func parseRequestWithParams() {
        let json = """
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"clipboard","arguments":{"action":"read"}}}
        """
        let data = json.data(using: .utf8)!
        let request = JSONRPCRequest.parse(from: data)

        #expect(request != nil)
        #expect(request?.id == 2)
        #expect(request?.method == "tools/call")
        #expect(request?.params["name"] as? String == "clipboard")
    }

    @Test("Malformed JSON returns nil")
    func malformedJSON() {
        let json = "not json at all"
        let data = json.data(using: .utf8)!
        let request = JSONRPCRequest.parse(from: data)

        #expect(request == nil)
    }

    @Test("JSON without method returns nil")
    func missingMethod() {
        let json = """
        {"jsonrpc":"2.0","id":1}
        """
        let data = json.data(using: .utf8)!
        let request = JSONRPCRequest.parse(from: data)

        #expect(request == nil)
    }

    // MARK: - Response Construction

    @Test("Success response has correct structure")
    func successResponse() {
        let response = JSONRPCServer.successResponse(id: 1, result: ["tools": []])

        #expect(response["jsonrpc"] as? String == "2.0")
        #expect(response["id"] as? Int == 1)
        #expect(response["result"] != nil)
    }

    @Test("Error response has correct structure")
    func errorResponse() {
        let response = JSONRPCServer.errorResponse(id: 1, code: -32601, message: "Method not found")

        #expect(response["jsonrpc"] as? String == "2.0")
        #expect(response["id"] as? Int == 1)

        let error = response["error"] as? [String: Any]
        #expect(error?["code"] as? Int == -32601)
        #expect(error?["message"] as? String == "Method not found")
    }

    @Test("Error response with nil id uses NSNull")
    func errorResponseNilID() {
        let response = JSONRPCServer.errorResponse(id: nil, code: -32700, message: "Parse error")

        #expect(response["id"] is NSNull)
    }
}
