import Foundation

/// Converts `Tool` protocol types to MCP-compatible JSON Schema dictionaries.
///
/// MCP expects tool definitions in the format:
/// ```json
/// {
///   "name": "clipboard",
///   "description": "Read or write the macOS clipboard",
///   "inputSchema": {
///     "type": "object",
///     "properties": { ... },
///     "required": [...]
///   }
/// }
/// ```
enum ToolBridge {
    /// Converts a `Tool` to an MCP tool definition dictionary.
    static func mcpToolDefinition(for tool: any Tool) -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []

        for param in tool.parameters {
            var prop: [String: Any] = [
                "type": param.type.rawValue,
                "description": param.description
            ]
            if let enumValues = param.enumValues {
                prop["enum"] = enumValues
            }
            properties[param.name] = prop

            if param.required {
                required.append(param.name)
            }
        }

        var inputSchema: [String: Any] = [
            "type": "object",
            "properties": properties
        ]
        if !required.isEmpty {
            inputSchema["required"] = required
        }

        return [
            "name": tool.name,
            "description": tool.description,
            "inputSchema": inputSchema
        ]
    }
}
