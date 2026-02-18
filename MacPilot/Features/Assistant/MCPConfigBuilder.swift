import Foundation

/// Builds the MCP configuration file that Claude CLI uses to discover MacPilot tools.
///
/// Writes a temporary JSON file pointing to the bundled `MacPilotMCP` binary.
/// The file is written to a temp directory and its path is passed to Claude CLI
/// via `--mcp-config`.
enum MCPConfigBuilder {
    /// Creates a temporary MCP config file and returns its path.
    ///
    /// The config tells Claude CLI to spawn `MacPilotMCP` as a stdio MCP server.
    ///
    /// - Returns: The file path to the temporary MCP config JSON.
    static func buildConfigFile() throws -> String {
        let mcpBinaryPath = resolveMCPBinaryPath()

        let config: [String: Any] = [
            "mcpServers": [
                "macpilot": [
                    "type": "stdio",
                    "command": mcpBinaryPath
                ] as [String: Any]
            ] as [String: Any]
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("macpilot-mcp-config.json")

        try data.write(to: configPath)
        return configPath.path
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
