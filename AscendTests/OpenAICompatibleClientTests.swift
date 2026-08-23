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

    private func makeClient() -> OpenAICompatibleClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return OpenAICompatibleClient(session: URLSession(configuration: configuration))
    }

    private func endpoint() -> AIEndpointDescriptor {
        AIEndpointDescriptor(
            id: UUID(),
            name: "Mock",
            baseURL: URL(string: "https://mock.local/v1")!,
            selectedModelID: "a-model",
            supportsStructuredOutputs: nil
        )
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
