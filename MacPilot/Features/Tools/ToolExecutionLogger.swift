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
}
