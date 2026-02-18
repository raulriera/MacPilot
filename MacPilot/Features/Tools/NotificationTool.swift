import Foundation

/// Sends macOS notifications via `NotificationManager`.
///
/// Delegates to the existing `NotificationManager.shared` actor
/// for authorization and delivery.
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

        let result = try await NotificationManager.shared.send(title: title, body: body)
        return .success(result)
    }
}
