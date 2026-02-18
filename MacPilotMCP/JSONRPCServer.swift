import Foundation

/// A parsed JSON-RPC 2.0 request.
struct JSONRPCRequest {
    let id: Int?
    let method: String
    let params: [String: Any]

    /// Parses a JSON-RPC request from raw JSON data.
    ///
    /// Returns `nil` if the data is not valid JSON or doesn't contain `method`.
    static func parse(from data: Data) -> JSONRPCRequest? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String else {
            return nil
        }

        let id = json["id"] as? Int
        let params = json["params"] as? [String: Any] ?? [:]
        return JSONRPCRequest(id: id, method: method, params: params)
    }
}

/// Minimal JSON-RPC 2.0 server over stdin/stdout.
///
/// Reads newline-delimited JSON from stdin, dispatches to a handler,
/// and writes JSON responses to stdout. This is the transport layer
/// for the MCP stdio protocol.
final class JSONRPCServer {
    typealias Handler = (JSONRPCRequest) async -> [String: Any]?

    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Runs the server, blocking on stdin until EOF.
    func run() async {
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty else { continue }

            guard let data = line.data(using: .utf8),
                  let request = JSONRPCRequest.parse(from: data) else {
                // Malformed JSON — send parse error if we can extract an id
                let errorResponse = Self.errorResponse(
                    id: extractID(from: line),
                    code: -32700,
                    message: "Parse error"
                )
                writeLine(errorResponse)
                continue
            }

            if let response = await handler(request) {
                writeLine(response)
            }
            // Notifications (no id) that return nil are silently dropped per JSON-RPC spec
        }
    }

    /// Constructs a JSON-RPC success response.
    static func successResponse(id: Int, result: Any) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ]
    }

    /// Constructs a JSON-RPC error response.
    static func errorResponse(id: Int?, code: Int, message: String) -> [String: Any] {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message
            ] as [String: Any]
        ]
        if let id {
            response["id"] = id
        } else {
            response["id"] = NSNull()
        }
        return response
    }

    // MARK: - Private

    private func writeLine(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        print(string)
        fflush(stdout)
    }

    private func extractID(from line: String) -> Int? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["id"] as? Int
    }
}
