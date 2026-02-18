import Foundation
import SwiftData

/// Persisted record of a tool execution for auditability.
///
/// Every tool invocation — whether successful or not — is logged with
/// its arguments, result, timing, and error status.
@Model
final class ToolExecutionLog {
    var id: UUID
    var toolName: String
    var arguments: String
    var resultContent: String
    var isError: Bool
    var executedAt: Date
    var durationMs: Int

    init(
        toolName: String,
        arguments: String,
        resultContent: String,
        isError: Bool,
        executedAt: Date = Date(),
        durationMs: Int
    ) {
        self.id = UUID()
        self.toolName = toolName
        self.arguments = arguments
        self.resultContent = resultContent
        self.isError = isError
        self.executedAt = executedAt
        self.durationMs = durationMs
    }
}
