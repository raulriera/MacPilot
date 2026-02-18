import Foundation
import SwiftData

/// Persists tool execution logs to SwiftData.
///
/// Follows the same singleton + `configure(with:)` pattern as `SessionManager`.
/// Must be configured with a `ModelContainer` before use.
@MainActor
final class ToolExecutionLogger {
    static let shared = ToolExecutionLogger()

    private var container: ModelContainer?

    private var context: ModelContext {
        guard let container else {
            fatalError("ToolExecutionLogger.configure(with:) must be called before use")
        }
        return container.mainContext
    }

    private init() {}

    /// Configures the logger with a SwiftData model container.
    func configure(with container: ModelContainer) {
        self.container = container
    }

    /// Logs a tool execution result.
    ///
    /// - Parameters:
    ///   - toolName: The name of the tool that was executed.
    ///   - arguments: The arguments passed to the tool, as a JSON string.
    ///   - result: The tool's execution result.
    ///   - durationMs: How long the execution took in milliseconds.
    func log(
        toolName: String,
        arguments: String,
        result: ToolResult,
        durationMs: Int
    ) throws {
        let entry = ToolExecutionLog(
            toolName: toolName,
            arguments: arguments,
            resultContent: result.content,
            isError: result.isError,
            durationMs: durationMs
        )
        context.insert(entry)
        try context.save()
    }

    /// Imports tool execution logs from a JSONL file written by the MCP server.
    ///
    /// Each line is a JSON object with: toolName, arguments, resultContent,
    /// isError, executedAt (ISO 8601), durationMs. The file is deleted after import.
    func importLogs(from filePath: String) {
        guard FileManager.default.fileExists(atPath: filePath) else { return }

        defer { try? FileManager.default.removeItem(atPath: filePath) }

        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else { return }

        let formatter = ISO8601DateFormatter()

        for line in content.split(separator: "\n") where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let toolName = json["toolName"] as? String,
                  let arguments = json["arguments"] as? String,
                  let resultContent = json["resultContent"] as? String,
                  let isError = json["isError"] as? Bool,
                  let durationMs = json["durationMs"] as? Int else {
                continue
            }

            let executedAt: Date
            if let dateString = json["executedAt"] as? String,
               let parsed = formatter.date(from: dateString) {
                executedAt = parsed
            } else {
                executedAt = Date()
            }

            let entry = ToolExecutionLog(
                toolName: toolName,
                arguments: arguments,
                resultContent: resultContent,
                isError: isError,
                executedAt: executedAt,
                durationMs: durationMs
            )
            context.insert(entry)
        }

        try? context.save()
    }
}
