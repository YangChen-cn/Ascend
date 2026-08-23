import XCTest
@testable import Ascend

final class EndpointURLBuilderTests: XCTestCase {
    private let builder = EndpointURLBuilder()

    func testBuildsOpenAICompatiblePathsFromRoot() throws {
        let base = try builder.normalizedBaseURL(from: "https://example.com/v1/")
        XCTAssertEqual(base.absoluteString, "https://example.com/v1")
        XCTAssertEqual(builder.modelsURL(baseURL: base).absoluteString, "https://example.com/v1/models")
        XCTAssertEqual(builder.chatCompletionsURL(baseURL: base).absoluteString, "https://example.com/v1/chat/completions")
    }

    func testRejectsFullEndpointAndMissingScheme() {
        XCTAssertThrowsError(try builder.normalizedBaseURL(from: "https://example.com/v1/models"))
        XCTAssertThrowsError(try builder.normalizedBaseURL(from: "example.com/v1"))
    }
}
