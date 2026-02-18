import Foundation

/// Sendable JSON value type for tool arguments.
///
/// Replaces `Any` in the `Tool` protocol for Swift 6 strict concurrency compliance.
/// Supports the JSON types needed by MCP tool parameters.
enum JSONValue: Sendable, Codable, Equatable, CustomStringConvertible {
    case string(String)
    case integer(Int)
    case number(Double)
    case boolean(Bool)
    case null

    var description: String {
        switch self {
        case .string(let value): value
        case .integer(let value): "\(value)"
        case .number(let value): "\(value)"
        case .boolean(let value): "\(value)"
        case .null: "null"
        }
    }

    /// Returns the underlying String value, if this is a `.string` case.
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Returns the underlying Int value, if this is an `.integer` case.
    var intValue: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }

    /// Returns the underlying Double value, if this is a `.number` case.
    var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    /// Returns the underlying Bool value, if this is a `.boolean` case.
    var boolValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported JSON value type"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

/// The type of a tool parameter, mapping to JSON Schema types.
enum ParameterType: String, Sendable {
    case string
    case integer
    case number
    case boolean
}

/// Describes a single parameter accepted by a tool.
struct ToolParameter: Sendable {
    let name: String
    let description: String
    let type: ParameterType
    let required: Bool
    let enumValues: [String]?

    init(
        name: String,
        description: String,
        type: ParameterType,
        required: Bool = true,
        enumValues: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.type = type
        self.required = required
        self.enumValues = enumValues
    }
}

/// The result of a tool execution.
struct ToolResult: Sendable {
    let content: String
    let isError: Bool

    static func success(_ content: String) -> ToolResult {
        ToolResult(content: content, isError: false)
    }

    static func failure(_ message: String) -> ToolResult {
        ToolResult(content: message, isError: true)
    }
}

/// A tool that Claude can invoke via MCP during a conversation.
///
/// Tools are registered in `ToolRegistry` and exposed to Claude CLI
/// through the MacPilotMCP binary. Permissions are handled by Claude CLI's
/// `--allowedTools` flag — no custom permission system needed.
protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }
    func execute(arguments: [String: JSONValue]) async throws -> ToolResult
}
