import Foundation
import SwiftData

/// Manages session CRUD operations via SwiftData.
///
/// Must be configured with a `ModelContainer` before use (typically in `MacPilotApp.init()`).
/// All operations run on the main actor since SwiftData's `mainContext` requires it.
@MainActor
final class SessionManager {
    static let shared = SessionManager()

    private var container: ModelContainer?

    private var context: ModelContext {
        guard let container else {
            fatalError("SessionManager.configure(with:) must be called before use")
        }
        return container.mainContext
    }

    private init() {}

    /// Configures the manager with a SwiftData model container.
    func configure(with container: ModelContainer) {
        self.container = container
    }

    /// Creates and persists a new session.
    ///
    /// - Parameters:
    ///   - claudeSessionID: The session ID returned by Claude CLI.
    ///   - name: A display name for the session.
    ///   - model: The Claude model used (default: "sonnet").
    /// - Returns: The newly created session.
    @discardableResult
    func createSession(
        claudeSessionID: String,
        name: String,
        model: String = "sonnet"
    ) throws -> Session {
        let session = Session(
            claudeSessionID: claudeSessionID,
            name: name,
            model: model
        )
        context.insert(session)
        try context.save()
        return session
    }

    /// Updates the `lastUsedAt` timestamp for a session.
    func touchSession(_ session: Session) throws {
        session.lastUsedAt = Date()
        try context.save()
    }

    /// Fetches a session by its local UUID.
    func session(byID id: UUID) throws -> Session? {
        let predicate = #Predicate<Session> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Returns all sessions ordered by most recently used.
    func allSessions() throws -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Returns the most recently used session, if any.
    func mostRecentSession() throws -> Session? {
        var descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Deletes a session from the store.
    func deleteSession(_ session: Session) throws {
        context.delete(session)
        try context.save()
    }
}
