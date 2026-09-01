import XCTest
@testable import Ascend

final class ChallengeEvidenceReviewPolicyTests: XCTestCase {
    func testPassingRequiresExplicitPassAndHighConfidence() {
        XCTAssertTrue(ChallengeEvidenceReviewPolicy.isPassing(.init(passed: true, confidence: 0.8, summary: "覆盖", failureReasons: [])))
        XCTAssertFalse(ChallengeEvidenceReviewPolicy.isPassing(.init(passed: true, confidence: 0.79, summary: "覆盖", failureReasons: [])))
        XCTAssertFalse(ChallengeEvidenceReviewPolicy.isPassing(.init(passed: false, confidence: 1, summary: "不足", failureReasons: ["缺测试"])))
    }

    func testFailedReviewGetsActionableFallbackReason() {
        let review = ChallengeEvidenceReviewPolicy.normalized(.init(passed: false, confidence: -0.2, summary: "", failureReasons: []))
        XCTAssertEqual(review.confidence, 0)
        XCTAssertFalse(review.failureReasons.isEmpty)
    }
}
