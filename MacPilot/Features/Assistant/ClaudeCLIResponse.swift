import Foundation

/// Represents a single message in the Claude CLI JSON output array.
///
/// When using `--output-format json`, the CLI returns a JSON object with a
/// `type` field. We care about `type: "result"` which contains the final answer.
struct CLIMessage: Decodable, Sendable {
    let type: String
    let subtype: String?
    let result: String?

    enum CodingKeys: String, CodingKey {
        case type
        case subtype
        case result
    }
}

enum CLIOutput {
    /// Parses the raw JSON data from Claude CLI and extracts the result text.
    ///
    /// The CLI outputs a JSON object with `type: "result"` containing the final response.
    static func parseResult(from data: Data) throws -> String {
        let message: CLIMessage
        do {
            message = try JSONDecoder().decode(CLIMessage.self, from: data)
        } catch {
            throw ClaudeCLIError.jsonDecodingFailed(underlying: error)
        }

        guard message.type == "result", let result = message.result else {
            throw ClaudeCLIError.noResultMessage
        }

        return result
    }
}
