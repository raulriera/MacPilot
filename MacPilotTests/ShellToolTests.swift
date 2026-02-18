import Testing
@testable import MacPilot

@Suite("ShellTool")
struct ShellToolTests {
    let tool = ShellTool()

    // MARK: - Parameter validation

    @Test("Missing command parameter returns error")
    func missingCommand() async throws {
        let result = try await tool.execute(arguments: [:])

        #expect(result.isError)
        #expect(result.content.contains("command"))
    }

    @Test("Empty command returns error")
    func emptyCommand() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("")
        ])

        #expect(result.isError)
        #expect(result.content.contains("empty"))
    }

    @Test("Whitespace-only command returns error")
    func whitespaceOnlyCommand() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("   \n\t  ")
        ])

        #expect(result.isError)
        #expect(result.content.contains("empty"))
    }

    @Test("Negative timeout returns error")
    func negativeTimeout() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("echo hello"),
            "timeout": .integer(-5)
        ])

        #expect(result.isError)
        #expect(result.content.contains("positive"))
    }

    @Test("Zero timeout returns error")
    func zeroTimeout() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("echo hello"),
            "timeout": .integer(0)
        ])

        #expect(result.isError)
        #expect(result.content.contains("positive"))
    }

    // MARK: - Successful execution

    @Test("Simple echo returns output")
    func simpleEcho() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("echo hello world")
        ])

        #expect(!result.isError)
        #expect(result.content.contains("hello world"))
        #expect(result.content.contains("[exit code: 0]"))
    }

    @Test("Piped command returns output")
    func pipedCommand() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("echo 'line1\nline2\nline3' | wc -l")
        ])

        #expect(!result.isError)
        #expect(result.content.contains("3"))
        #expect(result.content.contains("[exit code: 0]"))
    }

    @Test("Exit code is present in output")
    func exitCodePresent() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("echo test")
        ])

        #expect(!result.isError)
        #expect(result.content.contains("[exit code: 0]"))
    }

    // MARK: - Non-zero exit codes

    @Test("Non-zero exit code is reported")
    func nonZeroExitCode() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("exit 42")
        ])

        #expect(!result.isError)
        #expect(result.content.contains("[exit code: 42]"))
    }

    @Test("Command not found returns exit code 127")
    func commandNotFound() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("nonexistent_command_abc123")
        ])

        #expect(!result.isError)
        #expect(result.content.contains("[exit code: 127]"))
        #expect(result.content.contains("[stderr]"))
    }

    // MARK: - Stderr handling

    @Test("Stderr-only output is labeled")
    func stderrOnly() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("echo 'error message' >&2")
        ])

        #expect(!result.isError)
        #expect(result.content.contains("[stderr]"))
        #expect(result.content.contains("error message"))
    }

    @Test("Stdout and stderr are both captured")
    func stdoutAndStderr() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("echo 'out'; echo 'err' >&2")
        ])

        #expect(!result.isError)
        #expect(result.content.contains("out"))
        #expect(result.content.contains("[stderr]"))
        #expect(result.content.contains("err"))
    }

    // MARK: - Empty output

    @Test("Command with no output shows marker")
    func noOutput() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("true")
        ])

        #expect(!result.isError)
        #expect(result.content.contains("(no output)"))
        #expect(result.content.contains("[exit code: 0]"))
    }

    // MARK: - Timeout

    @Test("Long-running command is terminated after timeout")
    func timeout() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("sleep 60"),
            "timeout": .integer(1)
        ])

        #expect(!result.isError)
        #expect(result.content.contains("[timed out after 1s]"))
    }

    // MARK: - Custom timeout

    @Test("Custom timeout is respected")
    func customTimeout() async throws {
        let result = try await tool.execute(arguments: [
            "command": .string("echo fast"),
            "timeout": .integer(10)
        ])

        #expect(!result.isError)
        #expect(result.content.contains("fast"))
        #expect(!result.content.contains("timed out"))
    }

    // MARK: - Constants

    @Test("Max output length is 50,000")
    func maxOutputLength() {
        #expect(ShellTool.maxOutputLength == 50_000)
    }

    @Test("Default timeout is 30 seconds")
    func defaultTimeout() {
        #expect(ShellTool.defaultTimeout == 30)
    }
}
