import Foundation

/// MCP (Model Context Protocol) server that handles tool discovery and invocation.
///
/// Implements three MCP methods over JSON-RPC 2.0:
/// - `initialize` — returns server capabilities
/// - `tools/list` — returns tool definitions from `ToolRegistry`
/// - `tools/call` — executes a tool and returns the result
final class MCPServer {
    private let registry: ToolRegistry
    private let server: JSONRPCServer

    init(registry: ToolRegistry) {
        self.registry = registry
        self.server = JSONRPCServer { [registry] request in
            await MCPServer.handle(request: request, registry: registry)
        }
    }

    /// Starts the server, blocking on stdin until EOF.
    func run() async {
        await server.run()
    }

    // MARK: - Request Handling

    private static func handle(
        request: JSONRPCRequest,
        registry: ToolRegistry
    ) async -> [String: Any]? {
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
            return await handleToolsCall(id: id, params: request.params, registry: registry)
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
        registry: ToolRegistry
    ) async -> [String: Any] {
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

        let result: ToolResult
        do {
            result = try await tool.execute(arguments: arguments)
        } catch {
            result = .failure("Tool execution failed: \(error.localizedDescription)")
        }

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
