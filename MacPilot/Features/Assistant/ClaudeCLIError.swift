import Foundation

enum ClaudeCLIError: LocalizedError {
    case executableNotFound
    case processExitedWithError(code: Int32, stderr: String)
    case noOutputData
    case jsonDecodingFailed(underlying: Error)
    case noResultMessage
    case noSessionID

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "Claude CLI executable not found. Install it from https://claude.ai/download"
        case .processExitedWithError(let code, let stderr):
            "Claude CLI exited with code \(code): \(stderr)"
        case .noOutputData:
            "Claude CLI produced no output"
        case .jsonDecodingFailed(let underlying):
            "Failed to decode Claude CLI response: \(underlying.localizedDescription)"
        case .noResultMessage:
            "Claude CLI response contained no result message"
        case .noSessionID:
            "Claude CLI response did not include a session ID"
        }
    }
}
