import Foundation

/// MCP (Model Context Protocol) server that handles tool discovery and invocation.
///
/// Implements three MCP methods over JSON-RPC 2.0:
/// - `initialize` — returns server capabilities
/// - `tools/list` — returns tool definitions from `ToolRegistry`
/// - `tools/call` — executes a tool and returns the result
///
/// The read loop is fully synchronous. Only tool execution bridges to async
/// via a per-call semaphore, avoiding the deadlock that occurs when mixing
/// `readLine()` with Swift structured concurrency.
final class MCPServer {
    private let registry: ToolRegistry
    private let server: JSONRPCServer
    private let logFilePath: String?

    init(registry: ToolRegistry, logFilePath: String? = nil) {
        self.registry = registry
        self.logFilePath = logFilePath
        let reg = registry
        let logPath = logFilePath
        self.server = JSONRPCServer { request in
            MCPServer.handle(request: request, registry: reg, logFilePath: logPath)
        }
    }

    /// Starts the server, blocking on stdin until EOF.
    func run() {
        server.run()
    }

    // MARK: - Request Handling

    private static func handle(
        request: JSONRPCRequest,
        registry: ToolRegistry,
        logFilePath: String?
    ) -> [String: Any]? {
        guard let id = request.id else {
            // JSON-RPC notification — no response needed
            return nil
        }

        switch request.method {
        case "initialize":
            return handleInitialize(id: id)
        case "notifications/initialized":
            // Client acknowledgement — no response needed, but has an id sometimes
            return nil
        case "tools/list":
            return handleToolsList(id: id, registry: registry)
        case "tools/call":
            return handleToolsCall(id: id, params: request.params, registry: registry, logFilePath: logFilePath)
        default:
            return JSONRPCServer.errorResponse(
                id: id,
                code: -32601,
                message: "Method not found: \(request.method)"
            )
        }
    }

    private static func handleInitialize(id: Int) -> [String: Any] {
        JSONRPCServer.successResponse(id: id, result: [
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": [:] as [String: Any]
            ] as [String: Any],
            "serverInfo": [
                "name": "MacPilotMCP",
                "version": "0.1.0"
            ] as [String: Any]
        ] as [String: Any])
    }

    private static func handleToolsList(id: Int, registry: ToolRegistry) -> [String: Any] {
        let tools = registry.allTools.map { ToolBridge.mcpToolDefinition(for: $0) }
        return JSONRPCServer.successResponse(id: id, result: [
            "tools": tools
        ] as [String: Any])
    }

    private static func handleToolsCall(
        id: Int,
        params: [String: Any],
        registry: ToolRegistry,
        logFilePath: String?
    ) -> [String: Any] {
        guard let toolName = params["name"] as? String else {
            return JSONRPCServer.errorResponse(
                id: id,
                code: -32602,
                message: "Missing 'name' in tools/call params"
            )
        }

        guard let tool = registry.tool(named: toolName) else {
            return JSONRPCServer.errorResponse(
                id: id,
                code: -32602,
                message: "Unknown tool: \(toolName)"
            )
        }

        let rawArguments = params["arguments"] as? [String: Any] ?? [:]
        let arguments = convertArguments(rawArguments)

        // Bridge async tool execution to synchronous context.
        // Each tool call gets its own semaphore — no global deadlock risk.
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox()

        let capturedTool = tool
        let capturedArgs = arguments
        let startTime = DispatchTime.now()
        Task {
            do {
                let r = try await capturedTool.execute(arguments: capturedArgs)
                box.set(r)
            } catch {
                box.set(.failure("Tool execution failed: \(error.localizedDescription)"))
            }
            semaphore.signal()
        }

        semaphore.wait()
        let result = box.get()

        let elapsed = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        let durationMs = Int(elapsed / 1_000_000)
        writeLogEntry(
            toolName: toolName,
            arguments: rawArguments,
            result: result,
            durationMs: durationMs,
            logFilePath: logFilePath
        )

        return JSONRPCServer.successResponse(id: id, result: [
            "content": [
                [
                    "type": "text",
                    "text": result.content
                ] as [String: Any]
            ],
            "isError": result.isError
        ] as [String: Any])
    }

    /// Writes a tool execution log entry to the JSONL log file.
    private static func writeLogEntry(
        toolName: String,
        arguments: [String: Any],
        result: ToolResult,
        durationMs: Int,
        logFilePath: String?
    ) {
        guard let logFilePath else { return }

        let entry: [String: Any] = [
            "toolName": toolName,
            "arguments": (try? String(
                data: JSONSerialization.data(withJSONObject: arguments),
                encoding: .utf8
            )) ?? "{}",
            "resultContent": result.content,
            "isError": result.isError,
            "executedAt": ISO8601DateFormatter().string(from: Date()),
            "durationMs": durationMs
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: entry),
              var line = String(data: data, encoding: .utf8) else { return }

        line.append("\n")
        let fileURL = URL(fileURLWithPath: logFilePath)

        if FileManager.default.fileExists(atPath: logFilePath) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                handle.closeFile()
            }
        } else {
            try? Data(line.utf8).write(to: fileURL)
        }
    }

    /// Converts raw JSON `Any` values to `JSONValue` for the tool protocol.
    private static func convertArguments(_ raw: [String: Any]) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for (key, value) in raw {
            switch value {
            case let string as String:
                result[key] = .string(string)
            case let int as Int:
                result[key] = .integer(int)
            case let double as Double:
                result[key] = .number(double)
            case let bool as Bool:
                result[key] = .boolean(bool)
            default:
                // Convert unknown types to their string description
                result[key] = .string(String(describing: value))
            }
        }
        return result
    }
}

/// Thread-safe box for passing a `ToolResult` from an async Task back to
/// a synchronous caller via `DispatchSemaphore`. Marked `@unchecked Sendable`
/// because access is serialized by the semaphore (write before signal, read after wait).
private final class ResultBox: @unchecked Sendable {
    private var value: ToolResult = .failure("Tool execution timed out")

    func set(_ result: ToolResult) {
        value = result
    }

    func get() -> ToolResult {
        value
    }
}
