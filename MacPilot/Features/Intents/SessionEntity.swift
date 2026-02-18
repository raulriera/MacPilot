import AppIntents
import Foundation

/// Represents a MacPilot session in the App Intents system.
///
/// This entity allows Shortcuts to reference and pick sessions,
/// e.g. when continuing a conversation.
struct SessionEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Session"
    }

    static let defaultQuery = SessionEntityQuery()

    var id: UUID
    var name: String
    var lastUsedAt: Date

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(lastUsedAt.formatted(date: .abbreviated, time: .shortened))"
        )
    }
}

/// Query that backs the session entity picker in Shortcuts.
struct SessionEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [SessionEntity] {
        let manager = await SessionManager.shared
        return try await MainActor.run {
            try identifiers.compactMap { id in
                guard let session = try manager.session(byID: id) else { return nil }
                return SessionEntity(
                    id: session.id,
                    name: session.name,
                    lastUsedAt: session.lastUsedAt
                )
            }
        }
    }

    func suggestedEntities() async throws -> [SessionEntity] {
        let manager = await SessionManager.shared
        return try await MainActor.run {
            try manager.allSessions().map { session in
                SessionEntity(
                    id: session.id,
                    name: session.name,
                    lastUsedAt: session.lastUsedAt
                )
            }
        }
    }
}
