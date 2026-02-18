import Foundation

/// Builds the MCP configuration file that Claude CLI uses to discover MacPilot tools.
///
/// Writes a temporary JSON file pointing to the bundled `MacPilotMCP` binary.
/// The file is written to a temp directory and its path is passed to Claude CLI
/// via `--mcp-config`.
enum MCPConfigBuilder {
    /// The result of building an MCP config file.
    struct ConfigResult {
        let configPath: String
        let logFilePath: String
    }

    /// Creates a temporary MCP config file and returns its path along with the tool log file path.
    ///
    /// The config tells Claude CLI to spawn `MacPilotMCP` as a stdio MCP server.
    /// A unique log file path is passed as an argument so the MCP server can write
    /// tool execution logs that the main app imports after the CLI finishes.
    ///
    /// - Returns: Paths to the MCP config file and the tool log file.
    static func buildConfigFile() throws -> ConfigResult {
        let mcpBinaryPath = resolveMCPBinaryPath()
        let tempDir = FileManager.default.temporaryDirectory
        let logFilePath = tempDir.appendingPathComponent("macpilot-tool-log-\(UUID().uuidString).jsonl")

        let config: [String: Any] = [
            "mcpServers": [
                "macpilot": [
                    "type": "stdio",
                    "command": mcpBinaryPath,
                    "args": ["--log-file", logFilePath.path]
                ] as [String: Any]
            ] as [String: Any]
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        let configPath = tempDir.appendingPathComponent("macpilot-mcp-config.json")

        try data.write(to: configPath)
        return ConfigResult(configPath: configPath.path, logFilePath: logFilePath.path)
    }

    /// Resolves the path to the `MacPilotMCP` binary bundled inside the app.
    ///
    /// The binary is embedded in `MacPilot.app/Contents/MacOS/MacPilotMCP`
    /// via a copy files build phase.
    private static func resolveMCPBinaryPath() -> String {
        let bundle = Bundle.main
        let executableDir = bundle.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent("MacPilotMCP")

        return executableDir.path
    }
}
