import Testing
import Foundation
import SwiftData
@testable import MacPilot

@Suite("SessionManager", .serialized)
@MainActor
struct SessionManagerTests {

    /// Creates an in-memory model container for isolated testing.
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Session.self, configurations: configuration)
    }

    @Test("createSession persists a session and returns it")
    func createSession() throws {
        let container = try makeContainer()
        let manager = SessionManager.shared
        manager.configure(with: container)

        let session = try manager.createSession(
            claudeSessionID: "cli-sess-1",
            name: "Test Session"
        )

        #expect(session.claudeSessionID == "cli-sess-1")
        #expect(session.name == "Test Session")
        #expect(session.model == "sonnet")
    }

    @Test("session(byID:) finds a persisted session")
    func sessionByID() throws {
        let container = try makeContainer()
        let manager = SessionManager.shared
        manager.configure(with: container)

        let created = try manager.createSession(
            claudeSessionID: "cli-sess-2",
            name: "Findable"
        )

        let found = try manager.session(byID: created.id)
        #expect(found != nil)
        #expect(found?.claudeSessionID == "cli-sess-2")
    }

    @Test("session(byID:) returns nil for unknown UUID")
    func sessionByIDNotFound() throws {
        let container = try makeContainer()
        let manager = SessionManager.shared
        manager.configure(with: container)

        let found = try manager.session(byID: UUID())
        #expect(found == nil)
    }

    @Test("allSessions returns sessions ordered by most recent")
    func allSessionsOrdered() throws {
        let container = try makeContainer()
        let manager = SessionManager.shared
        manager.configure(with: container)

        let first = try manager.createSession(
            claudeSessionID: "s1",
            name: "First"
        )
        // Ensure distinct timestamps
        first.lastUsedAt = Date(timeIntervalSinceNow: -60)
        try container.mainContext.save()

        try manager.createSession(
            claudeSessionID: "s2",
            name: "Second"
        )

        let all = try manager.allSessions()
        #expect(all.count == 2)
        #expect(all[0].name == "Second")
        #expect(all[1].name == "First")
    }

    @Test("mostRecentSession returns the latest session")
    func mostRecentSession() throws {
        let container = try makeContainer()
        let manager = SessionManager.shared
        manager.configure(with: container)

        let first = try manager.createSession(
            claudeSessionID: "s1",
            name: "Older"
        )
        first.lastUsedAt = Date(timeIntervalSinceNow: -120)
        try container.mainContext.save()

        try manager.createSession(
            claudeSessionID: "s2",
            name: "Newer"
        )

        let recent = try manager.mostRecentSession()
        #expect(recent?.name == "Newer")
    }

    @Test("mostRecentSession returns nil when empty")
    func mostRecentSessionEmpty() throws {
        let container = try makeContainer()
        let manager = SessionManager.shared
        manager.configure(with: container)

        let recent = try manager.mostRecentSession()
        #expect(recent == nil)
    }

    @Test("touchSession updates lastUsedAt")
    func touchSession() throws {
        let container = try makeContainer()
        let manager = SessionManager.shared
        manager.configure(with: container)

        let session = try manager.createSession(
            claudeSessionID: "s1",
            name: "Touch Me"
        )
        let originalDate = session.lastUsedAt

        // Small delay to ensure timestamp differs
        session.lastUsedAt = Date(timeIntervalSinceNow: -10)
        try container.mainContext.save()

        try manager.touchSession(session)
        #expect(session.lastUsedAt > originalDate.addingTimeInterval(-10))
    }

    @Test("deleteSession removes the session")
    func deleteSession() throws {
        let container = try makeContainer()
        let manager = SessionManager.shared
        manager.configure(with: container)

        let session = try manager.createSession(
            claudeSessionID: "s1",
            name: "Delete Me"
        )
        let id = session.id

        try manager.deleteSession(session)

        let found = try manager.session(byID: id)
        #expect(found == nil)
    }
}
