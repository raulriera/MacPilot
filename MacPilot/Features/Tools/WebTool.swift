import Foundation

/// Fetches a URL via `URLSession` and returns the response body as text.
///
/// Only allows `http` and `https` schemes. Response body is truncated
/// to 50,000 characters to prevent excessive memory use.
struct WebTool: Tool {
    let name = "web"
    let description = "Fetch a URL and return its text content."

    let parameters: [ToolParameter] = [
        ToolParameter(
            name: "url",
            description: "The URL to fetch. Must use http or https scheme.",
            type: .string
        )
    ]

    /// Maximum response body length in characters.
    static let maxResponseLength = 50_000

    /// Request timeout in seconds.
    static let timeoutInterval: TimeInterval = 30

    func execute(arguments: [String: JSONValue]) async throws -> ToolResult {
        guard let urlString = arguments["url"]?.stringValue else {
            return .failure("Missing required parameter: url")
        }

        guard let url = URL(string: urlString) else {
            return .failure("Invalid URL: \(urlString)")
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return .failure("Only http and https URLs are supported.")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.timeoutInterval

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failure("Failed to fetch URL: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure("Unexpected response type.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            return .failure("HTTP \(httpResponse.statusCode)")
        }

        guard let body = String(data: data, encoding: .utf8) else {
            return .failure("Response body is not valid UTF-8 text.")
        }

        if body.count > Self.maxResponseLength {
            let truncated = String(body.prefix(Self.maxResponseLength))
            return .success(truncated + "\n\n[Truncated — response exceeded \(Self.maxResponseLength) characters]")
        }

        return .success(body)
    }
}
