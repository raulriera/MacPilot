import Foundation

/// Builds CLI argument arrays for Claude Code invocations.
enum PromptBuilder {
    /// The system prompt suffix appended to every MacPilot invocation.
    static let systemPrompt = """
        You are MacPilot, a personal AI assistant running as a macOS menu bar app. \
        Keep responses concise and actionable. Do not use markdown formatting unless \
        explicitly requested. Respond in plain text.
        """

    /// Constructs the arguments array for a single-turn prompt.
    ///
    /// - Parameters:
    ///   - prompt: The user's question or instruction.
    ///   - model: The Claude model to use (default: "sonnet").
    ///   - maxTurns: Maximum agentic turns (default: 1).
    /// - Returns: An array of CLI argument strings.
    static func arguments(
        for prompt: String,
        model: String = "sonnet",
        maxTurns: Int = 1
    ) -> [String] {
        [
            "-p", prompt,
            "--output-format", "json",
            "--model", model,
            "--max-turns", "\(maxTurns)",
            "--no-session-persistence",
            "--append-system-prompt", systemPrompt,
            "--tools", ""
        ]
    }
}
