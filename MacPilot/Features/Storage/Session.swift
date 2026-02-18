import Foundation
import SwiftData

/// Persists a Claude CLI conversation session.
///
/// Each session maps to a Claude CLI session ID that can be resumed
/// with `--resume`. MacPilot tracks metadata locally while Claude CLI
/// manages the actual conversation history.
@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var claudeSessionID: String
    var name: String
    var model: String
    var createdAt: Date
    var lastUsedAt: Date

    init(
        claudeSessionID: String,
        name: String,
        model: String = "sonnet"
    ) {
        self.id = UUID()
        self.claudeSessionID = claudeSessionID
        self.name = name
        self.model = model
        self.createdAt = Date()
        self.lastUsedAt = Date()
    }
}
