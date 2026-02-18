import Foundation

/// Executes shell commands via `/bin/zsh -c` and returns output.
///
/// Inherits the user's environment (PATH, HOME, etc.) so tools like
/// `git`, `gh`, and `swift` are available. Output is truncated to
/// prevent excessive memory use.
struct ShellTool: Tool {
    let name = "shell"
    let description = "Execute a shell command and return its output. Runs via /bin/zsh."

    let parameters: [ToolParameter] = [
        ToolParameter(
            name: "command",
            description: "The shell command to execute. Supports pipes, redirects, and shell features.",
            type: .string
        ),
        ToolParameter(
            name: "timeout",
            description: "Maximum execution time in seconds. Defaults to 30.",
            type: .integer,
            required: false
        )
    ]

    /// Maximum output length in characters before truncation.
    static let maxOutputLength = 50_000

    /// Default timeout in seconds when none is specified.
    static let defaultTimeout = 30

    func execute(arguments: [String: JSONValue]) async throws -> ToolResult {
        guard let command = arguments["command"]?.stringValue else {
            return .failure("Missing required parameter: command")
        }

        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure("Command cannot be empty.")
        }

        let timeout = arguments["timeout"]?.intValue ?? Self.defaultTimeout
        guard timeout > 0 else {
            return .failure("Timeout must be a positive integer.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", trimmed]
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return .failure("Failed to launch process: \(error.localizedDescription)")
        }

        let didFinish = await waitForProcess(process, timeout: timeout)

        if !didFinish {
            process.terminate()
            // Give the process a moment to clean up before collecting output.
            try? await Task.sleep(for: .milliseconds(100))
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if !didFinish {
            return .success(formatOutput(
                stdout: stdout,
                stderr: stderr,
                exitCode: process.terminationStatus,
                timedOut: true,
                timeout: timeout
            ))
        }

        return .success(formatOutput(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus,
            timedOut: false,
            timeout: timeout
        ))
    }

    /// Waits for the process to exit within the given timeout.
    private func waitForProcess(_ process: Process, timeout: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            let workItem = DispatchWorkItem {
                process.waitUntilExit()
            }
            DispatchQueue.global().async(execute: workItem)

            let result = workItem.wait(timeout: .now() + .seconds(timeout))
            continuation.resume(returning: result == .success)
        }
    }

    /// Formats stdout, stderr, and exit code into a single output string.
    private func formatOutput(
        stdout: String,
        stderr: String,
        exitCode: Int32,
        timedOut: Bool,
        timeout: Int
    ) -> String {
        var parts: [String] = []

        let trimmedOut = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOut.isEmpty {
            parts.append(trimmedOut)
        }

        let trimmedErr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedErr.isEmpty {
            parts.append("[stderr]\n\(trimmedErr)")
        }

        if parts.isEmpty {
            parts.append("(no output)")
        }

        if timedOut {
            parts.append("[timed out after \(timeout)s]")
        }

        parts.append("[exit code: \(exitCode)]")

        var output = parts.joined(separator: "\n\n")

        if output.count > Self.maxOutputLength {
            output = String(output.prefix(Self.maxOutputLength))
                + "\n\n[Truncated — output exceeded \(Self.maxOutputLength) characters]"
        }

        return output
    }
}
