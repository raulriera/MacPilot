import Foundation

/// MacPilotMCP — MCP stdio server for MacPilot tools.
///
/// Speaks JSON-RPC 2.0 over stdin/stdout. Claude CLI spawns this binary
/// when configured via `--mcp-config` and communicates tool calls through it.

let registry = ToolRegistryFactory.makeDefault()
let server = MCPServer(registry: registry)

// Run synchronously — the server blocks on stdin until EOF.
// No need for structured concurrency since this is a single-purpose CLI tool.
let semaphore = DispatchSemaphore(value: 0)

nonisolated(unsafe) let unsafeServer = server

Task {
    await unsafeServer.run()
    semaphore.signal()
}

semaphore.wait()
