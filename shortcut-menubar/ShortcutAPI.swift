import Foundation
import os

enum ShortcutAPIError: LocalizedError {
    case noAPIToken
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIToken:
            "No API token configured"
        case .httpError(let code):
            "HTTP error: \(code)"
        case .decodingError(let error):
            "Decoding failed: \(error.localizedDescription)"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        }
    }
}

private let logger = Logger(subsystem: "com.charpeni.shortcut-menubar", category: "API")

final class ShortcutAPI: Sendable {
    static let shared = ShortcutAPI()

    private let baseURL = URL(string: "https://api.app.shortcut.com")!
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private init() {}

    private func fetch<T: Decodable>(_ endpoint: String, query: [String: String] = [:]) async throws -> T {
        guard let token = TokenStorage.shared.getAPIToken(), !token.isEmpty else {
            throw ShortcutAPIError.noAPIToken
        }

        var url = baseURL.appendingPathComponent(endpoint)
        if !query.isEmpty {
            url.append(queryItems: query.map { URLQueryItem(name: $0.key, value: $0.value) })
        }

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "Shortcut-Token")

        let startTime = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await URLSession.shared.data(for: request)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShortcutAPIError.networkError(URLError(.badServerResponse))
        }

        let statusCode = httpResponse.statusCode
        logger.debug("[\(String(format: "%.0fms", elapsed), privacy: .public)] \(statusCode) \(endpoint, privacy: .public) (\(data.count) bytes)")

        guard (200...299).contains(statusCode) else {
            throw ShortcutAPIError.httpError(statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decoding error: \(error.localizedDescription, privacy: .public)")
            throw ShortcutAPIError.decodingError(error)
        }
    }

    func getCurrentMember() async throws -> MemberInfo {
        try await fetch("/api/v3/member")
    }

    func getMyStories(mentionName: String) async throws -> [Story] {
        let results: StorySearchResults = try await fetch(
            "/api/v3/search/stories",
            query: ["query": "owner:\(mentionName) !is:done", "page_size": "50"]
        )
        return results.data
    }

    func validateToken() async -> Bool {
        do {
            _ = try await getCurrentMember()
            return true
        } catch {
            return false
        }
    }

    func getWorkflows() async throws -> [Workflow] {
        try await fetch("/api/v3/workflows")
    }

    func getTeams() async throws -> [Team] {
        try await fetch("/api/v3/groups")
    }

    func getEpic(id: Int) async throws -> Epic {
        try await fetch("/api/v3/epics/\(id)")
    }
}
