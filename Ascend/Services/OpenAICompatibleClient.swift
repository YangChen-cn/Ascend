import Foundation

actor OpenAICompatibleClient: AIProviderClient {
    enum ClientError: LocalizedError {
        case invalidResponse
        case http(Int, String)
        case missingContent
        case invalidStructuredOutput(String)
        case timedOut(String)
        case connectionFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "AI 接口返回了无法识别的响应"
            case .http(let status, let message): "AI 接口错误 \(status)：\(message)"
            case .missingContent: "AI 响应没有文本内容"
            case .invalidStructuredOutput(let message): "AI 结构化输出解析失败：\(message)"
            case .timedOut(let context): "AI 接口响应超时（\(context)）。若使用长推理模型或海外接口，建议检查网络代理与代理可用性。"
            case .connectionFailed(let message): "无法连接至 AI 接口服务器：\(message)"
            }
        }
    }

    private let session: URLSession
    private let urlBuilder = EndpointURLBuilder()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = AppConstants.endpointTimeout
            configuration.timeoutIntervalForResource = AppConstants.endpointTimeout * 2
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func listModels(endpoint: AIEndpointDescriptor, apiKey: String) async throws -> [RemoteModel] {
        var request = URLRequest(url: urlBuilder.modelsURL(baseURL: endpoint.baseURL))
        request.httpMethod = "GET"
        applyHeaders(to: &request, apiKey: apiKey)
        let response: ModelListResponse = try await send(request, decode: ModelListResponse.self)
        return response.data.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    func test(endpoint: AIEndpointDescriptor, modelID: String, apiKey: String) async throws {
        let body = ChatRequest(
            model: modelID,
            messages: [ChatMessage(role: "user", content: "Reply with exactly OK")],
            temperature: 0,
            maxCompletionTokens: 8,
            responseFormat: nil
        )
        let response = try await chat(endpoint: endpoint, apiKey: apiKey, body: body)
        guard !response.choices.isEmpty else { throw ClientError.invalidResponse }
    }

    func analyze(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        activities: [CollectedActivity],
        candidateNodes: [KnowledgeCandidate]
    ) async throws -> AnalysisEnvelope {
        let input = AnalysisPromptInput(activities: activities, candidateNodes: candidateNodes)
        let inputData = try encoder.encode(input)
        let inputJSON = String(data: inputData, encoding: .utf8) ?? "{}"
        let messages = [
            ChatMessage(role: "developer", content: Self.analysisInstruction),
            ChatMessage(role: "user", content: inputJSON)
        ]
        let useStructuredOutput = endpoint.supportsStructuredOutputs != false
        let request = ChatRequest(
            model: modelID,
            messages: messages,
            temperature: 0.1,
            maxCompletionTokens: 3_000,
            responseFormat: useStructuredOutput ? .analysisEnvelope : nil
        )

        let response: ChatResponse
        do {
            response = try await chat(endpoint: endpoint, apiKey: apiKey, body: request, timeout: AppConstants.analysisTimeout)
        } catch ClientError.http(let status, _) where useStructuredOutput && (status == 400 || status == 422 || status == 404 || status == 415) {
            let fallback = ChatRequest(
                model: modelID,
                messages: messages,
                temperature: 0.1,
                maxCompletionTokens: 3_000,
                responseFormat: nil
            )
            response = try await chat(endpoint: endpoint, apiKey: apiKey, body: fallback, timeout: AppConstants.analysisTimeout)
        }

        guard let content = response.choices.first?.message.content else {
            throw ClientError.missingContent
        }
        do {
            let extracted = Self.extractJSON(content)
            return try decoder.decode(AnalysisEnvelope.self, from: Data(extracted.utf8))
        } catch {
            throw ClientError.invalidStructuredOutput(error.localizedDescription)
        }
    }

    private func chat(endpoint: AIEndpointDescriptor, apiKey: String, body: ChatRequest, timeout: TimeInterval = AppConstants.endpointTimeout) async throws -> ChatResponse {
        var request = URLRequest(url: urlBuilder.chatCompletionsURL(baseURL: endpoint.baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        applyHeaders(to: &request, apiKey: apiKey)
        request.httpBody = try encoder.encode(body)
        return try await send(request, decode: ChatResponse.self)
    }

    private func send<T: Decodable>(_ request: URLRequest, decode type: T.Type) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw ClientError.timedOut("超过 \(Int(request.timeoutInterval > 0 ? request.timeoutInterval : AppConstants.endpointTimeout)) 秒未响应")
            case .cannotConnectToHost, .cannotFindHost:
                throw ClientError.connectionFailed("无法连接至服务器，请检查 Base URL 与本地网络/代理设置")
            case .notConnectedToInternet:
                throw ClientError.connectionFailed("当前设备未连接到互联网")
            case .secureConnectionFailed, .serverCertificateUntrusted:
                throw ClientError.connectionFailed("SSL 证书安全校验失败，请检查 HTTPS 证书配置")
            default:
                throw ClientError.connectionFailed(urlError.localizedDescription)
            }
        } catch {
            throw error
        }

        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            let message = (try? decoder.decode(APIErrorEnvelope.self, from: data).error.message)
                ?? String(data: data.prefix(1_000), encoding: .utf8)
                ?? "未知错误"
            throw ClientError.http(http.statusCode, message)
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
    }

    private func applyHeaders(to request: inout URLRequest, apiKey: String) {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    static func extractJSON(_ text: String) -> String {
        var processed = text

        if let thinkStart = processed.range(of: "<think>") {
            if let thinkEnd = processed.range(of: "</think>") {
                processed.removeSubrange(thinkStart.lowerBound..<thinkEnd.upperBound)
            } else {
                processed.removeSubrange(thinkStart.lowerBound..<processed.endIndex)
            }
        }

        let trimmed = processed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("```") {
            let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
            var inCodeBlock = false
            var jsonLines: [String] = []
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if trimmedLine.hasPrefix("```") {
                    inCodeBlock.toggle()
                    continue
                }
                if inCodeBlock {
                    jsonLines.append(String(line))
                }
            }
            if !jsonLines.isEmpty {
                processed = jsonLines.joined(separator: "\n")
            }
        }

        if let firstBrace = processed.firstIndex(of: "{"),
           let lastBrace = processed.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            return String(processed[firstBrace...lastBrace])
        }

        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let analysisInstruction = """
    You analyze learning evidence for a private, local-first mastery tracker. Return only JSON matching the requested schema.
    Map each activity to the smallest useful technical knowledge point. Never award evidence for mere time spent.
    Use matchConfidence >= 0.85 only when an existing candidate is clearly the same concept. Use evidence kinds exactly:
    exposure, explanation, exercise, project, review, independentSolve.
    difficulty and independence must be between 0.8 and 1.2; confidence must be between 0.5 and 1.0.
    Keep summaries and rationales concise and evidence-based. Do not invent achievements.
    """

    private struct ModelListResponse: Decodable {
        let data: [RemoteModel]
    }

    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let maxCompletionTokens: Int
        let responseFormat: ResponseFormat?

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case maxCompletionTokens = "max_completion_tokens"
            case responseFormat = "response_format"
        }
    }

    private struct ResponseFormat: Encodable {
        let type: String
        let jsonSchema: JSONSchemaWrapper

        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }

        static let analysisEnvelope = Self(
            type: "json_schema",
            jsonSchema: JSONSchemaWrapper(
                name: "learning_analysis",
                strict: true,
                schema: AnalysisJSONSchema.value
            )
        )
    }

    private struct JSONSchemaWrapper: Encodable {
        let name: String
        let strict: Bool
        let schema: JSONValue
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message
        }

        struct Message: Decodable {
            let content: String?
        }
    }

    private struct APIErrorEnvelope: Decodable {
        let error: APIError

        struct APIError: Decodable {
            let message: String
        }
    }

    private struct AnalysisPromptInput: Encodable {
        let activities: [CollectedActivity]
        let candidateNodes: [KnowledgeCandidate]
    }
}
