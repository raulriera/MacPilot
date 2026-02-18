import Foundation

/// MacPilotMCP — MCP stdio server for MacPilot tools.
///
/// Speaks JSON-RPC 2.0 over stdin/stdout. Claude CLI spawns this binary
/// when configured via `--mcp-config` and communicates tool calls through it.
///
/// Fully synchronous — blocks on `readLine()` until stdin closes (EOF).

let registry = ToolRegistryFactory.makeDefault()
let server = MCPServer(registry: registry)
server.run()
