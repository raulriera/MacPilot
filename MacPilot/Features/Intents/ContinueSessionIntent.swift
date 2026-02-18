import AppIntents
import Foundation

/// Continues an existing MacPilot conversation session.
///
/// If no session is specified, falls back to the most recently used session.
/// This simplifies the Shortcuts loop workflow where the user doesn't need
/// to explicitly track session references.
struct ContinueSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Continue MacPilot Session"
    static let description: IntentDescription = "Continue an existing conversation session with MacPilot"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Session")
    var session: SessionEntity?

    @Parameter(title: "Message")
    var message: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let claudeSessionID = try await resolveClaudeSessionID()

        let response = try await ClaudeCLI.shared.continueSession(
            message,
            sessionID: claudeSessionID
        )

        // Touch the session on the main actor
        try await MainActor.run {
            let manager = SessionManager.shared
            if let entity = session,
               let found = try manager.session(byID: entity.id) {
                try manager.touchSession(found)
            } else if let recent = try manager.mostRecentSession() {
                try manager.touchSession(recent)
            }
        }

        return .result(value: response)
    }

    /// Resolves the Claude CLI session ID, falling back to the most recent session.
    private func resolveClaudeSessionID() async throws -> String {
        try await MainActor.run {
            let manager = SessionManager.shared

            if let entity = session {
                guard let found = try manager.session(byID: entity.id) else {
                    throw ContinueSessionError.sessionNotFound
                }
                return found.claudeSessionID
            }

            guard let recent = try manager.mostRecentSession() else {
                throw ContinueSessionError.noSessions
            }
            return recent.claudeSessionID
        }
    }
}

/// Errors specific to the Continue Session intent.
enum ContinueSessionError: LocalizedError {
    case sessionNotFound
    case noSessions

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            "The selected session could not be found"
        case .noSessions:
            "No sessions exist yet. Use \"Start MacPilot Session\" first."
        }
    }
}
