import Testing
@testable import MacPilot

@Suite("ToolRegistry")
struct ToolRegistryTests {

    @Test("Default registry contains all built-in tools")
    func defaultRegistryContainsAllTools() {
        let registry = ToolRegistryFactory.makeDefault()

        #expect(registry.allTools.count == 3)
    }

    @Test("Lookup by name returns the correct tool")
    func lookupByName() {
        let registry = ToolRegistryFactory.makeDefault()

        let clipboard = registry.tool(named: "clipboard")
        #expect(clipboard != nil)
        #expect(clipboard?.name == "clipboard")

        let notification = registry.tool(named: "notification")
        #expect(notification != nil)
        #expect(notification?.name == "notification")

        let web = registry.tool(named: "web")
        #expect(web != nil)
        #expect(web?.name == "web")
    }

    @Test("Lookup for unknown tool returns nil")
    func unknownToolReturnsNil() {
        let registry = ToolRegistryFactory.makeDefault()

        #expect(registry.tool(named: "nonexistent") == nil)
        #expect(registry.tool(named: "") == nil)
    }

    @Test("Each tool has a non-empty description")
    func toolsHaveDescriptions() {
        let registry = ToolRegistryFactory.makeDefault()

        for tool in registry.allTools {
            #expect(!tool.description.isEmpty, "Tool '\(tool.name)' has an empty description")
        }
    }

    @Test("Each tool has at least one parameter")
    func toolsHaveParameters() {
        let registry = ToolRegistryFactory.makeDefault()

        for tool in registry.allTools {
            #expect(!tool.parameters.isEmpty, "Tool '\(tool.name)' has no parameters")
        }
    }
}
