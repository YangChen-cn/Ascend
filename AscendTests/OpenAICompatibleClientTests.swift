import Foundation
import XCTest
@testable import Ascend

final class OpenAICompatibleClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testModelDiscoveryUsesRootPathAndBearerKey() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/models")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer local-secret")
            let data = Data(#"{"data":[{"id":"z-model","owned_by":"local"},{"id":"a-model","owned_by":"local"}]}"#.utf8)
            return (200, data)
        }

        let models = try await makeClient().listModels(endpoint: endpoint(), apiKey: "local-secret")
        XCTAssertEqual(models.map(\.id), ["a-model", "z-model"])
    }

    func testUnauthorizedResponsePreservesHTTPStatus() async {
        StubURLProtocol.handler = { _ in
            (401, Data(#"{"error":{"message":"invalid key"}}"#.utf8))
        }

        do {
            _ = try await makeClient().listModels(endpoint: endpoint(), apiKey: "bad-key")
            XCTFail("Expected a 401 error")
        } catch OpenAICompatibleClient.ClientError.http(let status, let message) {
            XCTAssertEqual(status, 401)
            XCTAssertEqual(message, "invalid key")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAnalyzeAcceptsMissingLocalIDsAndSuggestionCollections() async throws {
        let activityID = UUID()
        StubURLProtocol.handler = { _ in
            let content = """
            {
              "sessionSummary": "完成分析",
              "evidence": [{
                "activityID": "\(activityID.uuidString)",
                "knowledgeName": "Swift Concurrency",
                "matchedNodeID": null,
                "matchConfidence": 0.72,
                "kind": "project",
                "difficulty": 1.0,
                "independence": 1.1,
                "confidence": 0.9,
                "summary": "使用 actor 隔离状态",
                "rationale": "提交包含 actor 实现"
              }]
            }
            """
            return (200, try chatResponse(content: content))
        }

        let envelope = try await makeClient().analyze(
            endpoint: endpoint(supportsStructuredOutputs: false),
            modelID: "a-model",
            apiKey: "local-secret",
            activities: [activity(id: activityID)],
            candidateNodes: []
        )

        XCTAssertEqual(envelope.evidence.first?.activityID, activityID)
        XCTAssertNotNil(envelope.evidence.first?.id)
        XCTAssertTrue(envelope.nodeSuggestions.isEmpty)
        XCTAssertTrue(envelope.edgeSuggestions.isEmpty)
    }

    func testAnalyzeRepairsMissingScoreCriticalFieldOnce() async throws {
        let activityID = UUID()
        let requestCount = LockedCounter()
        StubURLProtocol.handler = { _ in
            let count = requestCount.increment()
            if count == 1 {
                return (200, try chatResponse(content: #"{"sessionSummary":"首次","evidence":[{"knowledgeName":"Swift"}]}"#))
            }

            let repaired = """
            {
              "sessionSummary": "已修复",
              "evidence": [{
                "activityID": "\(activityID.uuidString)",
                "knowledgeName": "Swift",
                "matchedNodeID": null,
                "matchConfidence": 0.9,
                "kind": "explanation",
                "difficulty": 1.0,
                "independence": 1.0,
                "confidence": 0.9,
                "summary": "理解并发",
                "rationale": "可追溯证据"
              }],
              "nodeSuggestions": [],
              "edgeSuggestions": [],
              "challengeSuggestion": null
            }
            """
            return (200, try chatResponse(content: repaired))
        }

        let envelope = try await makeClient().analyze(
            endpoint: endpoint(supportsStructuredOutputs: false),
            modelID: "a-model",
            apiKey: "local-secret",
            activities: [activity(id: activityID)],
            candidateNodes: []
        )

        XCTAssertEqual(requestCount.value, 2)
        XCTAssertEqual(envelope.sessionSummary, "已修复")
        XCTAssertEqual(envelope.evidence.first?.activityID, activityID)
    }

    func testAnalyzeDoesNotRetryWhenRepairIsDisabled() async {
        let activityID = UUID()
        let requestCount = LockedCounter()
        StubURLProtocol.handler = { _ in
            _ = requestCount.increment()
            return (200, try chatResponse(content: #"{"sessionSummary":"首次","evidence":[{"knowledgeName":"Swift"}]}"#))
        }

        do {
            _ = try await makeClient().analyze(
                endpoint: endpoint(supportsStructuredOutputs: false),
                modelID: "a-model",
                apiKey: "local-secret",
                activities: [activity(id: activityID)],
                candidateNodes: [],
                options: AnalysisOptions(
                    maximumKnowledgePointsPerActivity: 3,
                    repairsMalformedOutput: false
                )
            )
            XCTFail("Expected invalid structured output")
        } catch {
            XCTAssertEqual(requestCount.value, 1)
        }
    }

    func testDecodingErrorIncludesMissingFieldPath() {
        struct Container: Decodable {
            let evidence: [Item]

            struct Item: Decodable {
                let activityID: UUID
            }
        }

        do {
            _ = try JSONDecoder().decode(Container.self, from: Data(#"{"evidence":[{}]}"#.utf8))
            XCTFail("Expected a decoding error")
        } catch {
            XCTAssertEqual(
                OpenAICompatibleClient.describeDecodingError(error),
                "缺少字段 evidence[0].activityID"
            )
        }
    }

    func testInitialInstructionRequiresCompleteChineseOutputAndBoundedGranularity() {
        let instruction = OpenAICompatibleClient.analysisInstruction

        XCTAssertTrue(instruction.contains("sessionSummary 必须是非空字符串"))
        XCTAssertTrue(instruction.contains("必须使用简体中文"))
        XCTAssertTrue(instruction.contains("硬性上限为 3 个"))
        XCTAssertTrue(instruction.contains("proposedName 必须与对应 knowledgeName 完全一致"))
    }

    func testEnvelopePolicyDeduplicatesAndCapsKnowledgePointsPerActivity() throws {
        let activityID = UUID()
        let evidence = ["进程", "信号", "文件描述符", "Makefile", "进程"].map { name in
            AnalyzedEvidence(
                activityID: activityID,
                knowledgeName: name,
                matchedNodeID: nil,
                matchConfidence: 0.7,
                kind: .explanation,
                difficulty: 1,
                independence: 1,
                confidence: 0.9,
                summary: "中文摘要",
                rationale: "中文依据"
            )
        }
        let envelope = AnalysisEnvelope(
            sessionSummary: "本次学习了嵌入式 Linux 基础。",
            evidence: evidence,
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: nil
        )

        let normalized = try AnalysisEnvelopePolicy.normalized(envelope)

        XCTAssertEqual(normalized.evidence.map(\.knowledgeName), ["进程", "信号", "文件描述符"])
    }

    func testEnvelopePolicyUsesConfiguredKnowledgePointLimit() throws {
        let activityID = UUID()
        let evidence = ["进程", "信号", "文件描述符"].map { name in
            AnalyzedEvidence(
                activityID: activityID,
                knowledgeName: name,
                matchedNodeID: nil,
                matchConfidence: 0.7,
                kind: .explanation,
                difficulty: 1,
                independence: 1,
                confidence: 0.9,
                summary: "中文摘要",
                rationale: "中文依据"
            )
        }
        let envelope = AnalysisEnvelope(
            sessionSummary: "本次学习了进程基础。",
            evidence: evidence,
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: nil
        )

        let normalized = try AnalysisEnvelopePolicy.normalized(
            envelope,
            maximumKnowledgePointsPerActivity: 1
        )

        XCTAssertEqual(normalized.evidence.map(\.knowledgeName), ["进程"])
    }

    private func makeClient() -> OpenAICompatibleClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return OpenAICompatibleClient(session: URLSession(configuration: configuration))
    }

    private func endpoint(supportsStructuredOutputs: Bool? = nil) -> AIEndpointDescriptor {
        AIEndpointDescriptor(
            id: UUID(),
            name: "Mock",
            baseURL: URL(string: "https://mock.local/v1")!,
            selectedModelID: "a-model",
            supportsStructuredOutputs: supportsStructuredOutputs
        )
    }

    private func activity(id: UUID) -> CollectedActivity {
        CollectedActivity(
            id: id,
            sourceID: UUID(),
            sourceKind: .manual,
            timestamp: .now,
            fingerprint: "test-fingerprint",
            title: "Test",
            sourceLocator: "manual:test",
            summary: "Test activity",
            excerpt: "actor"
        )
    }
}

private func chatResponse(content: String) throws -> Data {
    try JSONSerialization.data(withJSONObject: [
        "choices": [["message": ["content": content]]]
    ])
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
