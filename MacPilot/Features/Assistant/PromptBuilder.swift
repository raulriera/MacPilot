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
    ///   - mcpConfigPath: Optional path to an MCP config file. When provided,
    ///     adds `--mcp-config` and removes `--tools ""` so Claude can use MCP tools.
    /// - Returns: An array of CLI argument strings.
    static func arguments(
        for prompt: String,
        model: String = "sonnet",
        maxTurns: Int = 1,
        mcpConfigPath: String? = nil
    ) -> [String] {
        var args = [
            "-p", prompt,
            "--output-format", "json",
            "--model", model,
            "--max-turns", "\(maxTurns)",
            "--no-session-persistence",
            "--append-system-prompt", systemPrompt
        ]

        if let mcpConfigPath {
            args += ["--mcp-config", mcpConfigPath]
            args += ["--allowedTools", "mcp__macpilot__clipboard mcp__macpilot__notification mcp__macpilot__web"]
        } else {
            args += ["--tools", ""]
        }

        return args
    }

    /// Constructs arguments for starting a new persistent session.
    ///
    /// Same as `arguments()` but omits `--no-session-persistence` so Claude CLI
    /// creates a session that can be resumed later.
    ///
    /// - Parameters:
    ///   - prompt: The user's question or instruction.
    ///   - model: The Claude model to use (default: "sonnet").
    ///   - maxTurns: Maximum agentic turns (default: 3).
    ///   - mcpConfigPath: Optional path to an MCP config file.
    /// - Returns: An array of CLI argument strings.
    static func sessionArguments(
        for prompt: String,
        model: String = "sonnet",
        maxTurns: Int = 3,
        mcpConfigPath: String? = nil
    ) -> [String] {
        var args = [
            "-p", prompt,
            "--output-format", "json",
            "--model", model,
            "--max-turns", "\(maxTurns)",
            "--append-system-prompt", systemPrompt
        ]

        if let mcpConfigPath {
            args += ["--mcp-config", mcpConfigPath]
            args += ["--allowedTools", "mcp__macpilot__clipboard mcp__macpilot__notification mcp__macpilot__web"]
        } else {
            args += ["--tools", ""]
        }

        return args
    }

    /// Constructs arguments for resuming an existing session.
    ///
    /// Uses `--resume` with the Claude CLI session ID and omits
    /// `--no-session-persistence` to maintain session continuity.
    ///
    /// - Parameters:
    ///   - prompt: The user's follow-up message.
    ///   - sessionID: The Claude CLI session ID to resume.
    ///   - model: The Claude model to use (default: "sonnet").
    ///   - maxTurns: Maximum agentic turns (default: 3).
    ///   - mcpConfigPath: Optional path to an MCP config file.
    /// - Returns: An array of CLI argument strings.
    static func resumeArguments(
        for prompt: String,
        sessionID: String,
        model: String = "sonnet",
        maxTurns: Int = 3,
        mcpConfigPath: String? = nil
    ) -> [String] {
        var args = [
            "-p", prompt,
            "--output-format", "json",
            "--model", model,
            "--max-turns", "\(maxTurns)",
            "--resume", sessionID,
            "--append-system-prompt", systemPrompt
        ]

        if let mcpConfigPath {
            args += ["--mcp-config", mcpConfigPath]
            args += ["--allowedTools", "mcp__macpilot__clipboard mcp__macpilot__notification mcp__macpilot__web"]
        } else {
            args += ["--tools", ""]
        }

        return args
    }
}
