import Foundation

/// Sends macOS notifications.
///
/// Uses `osascript` (AppleScript) to send notifications, which works from
/// both the main app and the MCP command-line binary. `UNUserNotificationCenter`
/// requires a full app context with a bundle ID, which the MCP binary lacks.
struct NotificationTool: Tool {
    let name = "notification"
    let description = "Send a macOS notification with a title and body."

    let parameters: [ToolParameter] = [
        ToolParameter(
            name: "title",
            description: "The notification title.",
            type: .string
        ),
        ToolParameter(
            name: "body",
            description: "The notification body text.",
            type: .string
        )
    ]

    func execute(arguments: [String: JSONValue]) async throws -> ToolResult {
        guard let title = arguments["title"]?.stringValue else {
            return .failure("Missing required parameter: title")
        }

        guard let body = arguments["body"]?.stringValue else {
            return .failure("Missing required parameter: body")
        }

        return sendViaOsascript(title: title, body: body)
    }

    private func sendViaOsascript(title: String, body: String) -> ToolResult {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return .success("Notification sent.")
            } else {
                return .failure("osascript exited with code \(process.terminationStatus)")
            }
        } catch {
            return .failure("Failed to send notification: \(error.localizedDescription)")
        }
    }
}
