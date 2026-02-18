import AppKit

/// Reads and writes the macOS clipboard via `NSPasteboard`.
///
/// Actions:
/// - `read`: Returns the current clipboard text content.
/// - `write`: Sets the clipboard to the provided text.
struct ClipboardTool: Tool {
    let name = "clipboard"
    let description = "Read or write the macOS clipboard."

    let parameters: [ToolParameter] = [
        ToolParameter(
            name: "action",
            description: "The action to perform: 'read' to get clipboard contents, 'write' to set them.",
            type: .string,
            enumValues: ["read", "write"]
        ),
        ToolParameter(
            name: "content",
            description: "The text to write to the clipboard. Required when action is 'write'.",
            type: .string,
            required: false
        )
    ]

    func execute(arguments: [String: JSONValue]) async throws -> ToolResult {
        guard let action = arguments["action"]?.stringValue else {
            return .failure("Missing required parameter: action")
        }

        switch action {
        case "read":
            return await readClipboard()
        case "write":
            guard let content = arguments["content"]?.stringValue else {
                return .failure("Missing required parameter: content (needed for write action)")
            }
            return await writeClipboard(content)
        default:
            return .failure("Unknown action: \(action). Use 'read' or 'write'.")
        }
    }

    @MainActor
    private func readClipboard() -> ToolResult {
        guard let content = NSPasteboard.general.string(forType: .string) else {
            return .success("Clipboard is empty.")
        }
        return .success(content)
    }

    @MainActor
    private func writeClipboard(_ content: String) -> ToolResult {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        return .success("Clipboard updated.")
    }
}
