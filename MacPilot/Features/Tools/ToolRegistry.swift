import Foundation

/// Immutable registry for looking up tools by name.
///
/// Constructed once at startup and shared between the main app
/// and the MCP server binary.
struct ToolRegistry: Sendable {
    private let tools: [String: any Tool]

    init(tools: [any Tool]) {
        var lookup: [String: any Tool] = [:]
        for tool in tools {
            lookup[tool.name] = tool
        }
        self.tools = lookup
    }

    /// Looks up a tool by its registered name.
    func tool(named name: String) -> (any Tool)? {
        tools[name]
    }

    /// All registered tools, in no particular order.
    var allTools: [any Tool] {
        Array(tools.values)
    }
}

/// Factory for creating the default tool registry with all built-in tools.
enum ToolRegistryFactory {
    static func makeDefault() -> ToolRegistry {
        ToolRegistry(tools: [
            ClipboardTool(),
            NotificationTool(),
            WebTool(),
            ShellTool()
        ])
    }
}
