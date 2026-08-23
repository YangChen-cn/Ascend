import Foundation

struct EndpointURLBuilder: Sendable {
    enum URLBuilderError: LocalizedError {
        case invalidBaseURL
        case fullEndpointNotAllowed

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL: "Base URL 无效，请填写包含 http 或 https 的地址"
            case .fullEndpointNotAllowed: "请填写 API 根路径，不要填写 /models 或 /chat/completions 完整地址"
            }
        }
    }

    func normalizedBaseURL(from string: String) throws -> URL {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            throw URLBuilderError.invalidBaseURL
        }
        let loweredPath = components.path.lowercased()
        guard !loweredPath.hasSuffix("/models"), !loweredPath.hasSuffix("/chat/completions") else {
            throw URLBuilderError.fullEndpointNotAllowed
        }
        while components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let url = components.url else { throw URLBuilderError.invalidBaseURL }
        return url
    }

    func modelsURL(baseURL: URL) -> URL {
        baseURL.appending(path: "models")
    }

    func chatCompletionsURL(baseURL: URL) -> URL {
        baseURL.appending(path: "chat/completions")
    }
}
