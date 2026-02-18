import Foundation

/// Actor that wraps Claude Code CLI invocations via `Process`.
///
/// Serializes subprocess calls and provides a clean async interface
/// for the rest of the app.
actor ClaudeCLI {
    static let shared = ClaudeCLI()

    /// Known paths where the Claude CLI might be installed.
    private static let knownPaths = [
        "\(NSHomeDirectory())/.local/bin/claude",
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude"
    ]

    /// Cached executable path, resolved once on first use.
    private var cachedExecutablePath: String?

    private init() {}

    // MARK: - Public API

    /// Sends a single-turn prompt to Claude with MCP tools enabled.
    ///
    /// Claude can invoke MacPilot tools (clipboard, notification, web) during
    /// the conversation. Uses more turns (default: 5) to allow tool calls.
    ///
    /// - Parameters:
    ///   - prompt: The user's question or instruction.
    ///   - model: The Claude model to use (default: "sonnet").
    ///   - maxTurns: Maximum agentic turns (default: 5).
    /// - Returns: Claude's text response.
    func askWithTools(
        _ prompt: String,
        model: String = "sonnet",
        maxTurns: Int = 5
    ) async throws -> String {
        let config = try MCPConfigBuilder.buildConfigFile()
        let executablePath = try resolveExecutablePath()
        let arguments = PromptBuilder.arguments(
            for: prompt,
            model: model,
            maxTurns: maxTurns,
            mcpConfigPath: config.configPath
        )
        let (stdout, _) = try await runProcess(executablePath: executablePath, arguments: arguments)

        // Import tool execution logs written by the MCP server
        await ToolExecutionLogger.shared.importLogs(from: config.logFilePath)

        guard let data = stdout.data(using: .utf8), !data.isEmpty else {
            throw ClaudeCLIError.noOutputData
        }

        return try CLIOutput.parseResult(from: data)
    }

    /// Sends a single-turn prompt to Claude and returns the text response.
    ///
    /// - Parameters:
    ///   - prompt: The user's question or instruction.
    ///   - model: The Claude model to use (default: "sonnet").
    /// - Returns: Claude's text response.
    func ask(_ prompt: String, model: String = "sonnet") async throws -> String {
        let executablePath = try resolveExecutablePath()
        let arguments = PromptBuilder.arguments(for: prompt, model: model)
        let (stdout, _) = try await runProcess(executablePath: executablePath, arguments: arguments)

        guard let data = stdout.data(using: .utf8), !data.isEmpty else {
            throw ClaudeCLIError.noOutputData
        }

        return try CLIOutput.parseResult(from: data)
    }

    /// Starts a new persistent session with Claude.
    ///
    /// Unlike `ask()`, this creates a session that can be resumed later
    /// via `continueSession()`. Returns both the response and the session ID
    /// needed for resumption.
    ///
    /// - Parameters:
    ///   - prompt: The user's initial question or instruction.
    ///   - model: The Claude model to use (default: "sonnet").
    /// - Returns: A tuple of Claude's text response and the session ID.
    func startSession(
        _ prompt: String,
        model: String = "sonnet"
    ) async throws -> (response: String, sessionID: String) {
        let executablePath = try resolveExecutablePath()
        let arguments = PromptBuilder.sessionArguments(for: prompt, model: model)
        let (stdout, _) = try await runProcess(executablePath: executablePath, arguments: arguments)

        guard let data = stdout.data(using: .utf8), !data.isEmpty else {
            throw ClaudeCLIError.noOutputData
        }

        let parsed = try CLIOutput.parseSessionResult(from: data)
        return (response: parsed.result, sessionID: parsed.sessionID)
    }

    /// Continues an existing session with a follow-up message.
    ///
    /// Uses `--resume` with the Claude CLI session ID to maintain
    /// conversation context across turns.
    ///
    /// - Parameters:
    ///   - prompt: The user's follow-up message.
    ///   - sessionID: The Claude CLI session ID to resume.
    ///   - model: The Claude model to use (default: "sonnet").
    /// - Returns: Claude's text response.
    func continueSession(
        _ prompt: String,
        sessionID: String,
        model: String = "sonnet"
    ) async throws -> String {
        let executablePath = try resolveExecutablePath()
        let arguments = PromptBuilder.resumeArguments(
            for: prompt,
            sessionID: sessionID,
            model: model
        )
        let (stdout, _) = try await runProcess(executablePath: executablePath, arguments: arguments)

        guard let data = stdout.data(using: .utf8), !data.isEmpty else {
            throw ClaudeCLIError.noOutputData
        }

        return try CLIOutput.parseResult(from: data)
    }

    // MARK: - Executable Resolution

    /// Resolves the path to the Claude CLI executable.
    ///
    /// Checks known installation paths first, then falls back to `which claude`.
    /// The result is cached for subsequent calls.
    private func resolveExecutablePath() throws -> String {
        if let cached = cachedExecutablePath {
            return cached
        }

        let fileManager = FileManager.default

        // Check known paths
        for path in Self.knownPaths where fileManager.isExecutableFile(atPath: path) {
            cachedExecutablePath = path
            return path
        }

        // Fall back to `which claude`
        if let whichPath = try? runWhich() {
            cachedExecutablePath = whichPath
            return whichPath
        }

        throw ClaudeCLIError.executableNotFound
    }

    /// Runs `which claude` to locate the executable on PATH.
    private func runWhich() throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }

    // MARK: - Process Execution

    /// Runs the Claude CLI as a subprocess and returns stdout/stderr.
    ///
    /// Bridges `Process.terminationHandler` to Swift concurrency via
    /// `withCheckedThrowingContinuation`.
    private func runProcess(
        executablePath: String,
        arguments: [String]
    ) async throws -> (stdout: String, stderr: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            // Strip CLAUDE_CODE env var to avoid nested-session errors
            var environment = ProcessInfo.processInfo.environment
            environment.removeValue(forKey: "CLAUDECODE")
            process.environment = environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { _ in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    continuation.resume(
                        throwing: ClaudeCLIError.processExitedWithError(
                            code: process.terminationStatus,
                            stderr: stderr
                        )
                    )
                } else {
                    continuation.resume(returning: (stdout, stderr))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ClaudeCLIError.executableNotFound)
            }
        }
    }
}
