import XCTest
@testable import Ascend

final class AssessmentAdaptiveEngineTests: XCTestCase {
    private let engine = AssessmentAdaptiveEngine()

    func testStartingTierFollowsCurrentProbability() {
        XCTAssertEqual(engine.startingTier(probability: nil), .foundational)
        XCTAssertEqual(engine.startingTier(probability: 0.39), .foundational)
        XCTAssertEqual(engine.startingTier(probability: 0.40), .application)
        XCTAssertEqual(engine.startingTier(probability: 0.70), .transfer)
    }

    func testStopConditionRequiresThreeAndNeverExceedsFive() {
        XCTAssertFalse(engine.shouldStop(responses: []))
        XCTAssertFalse(engine.shouldStop(responses: [response(correct: true), response(correct: true)]))
        XCTAssertTrue(engine.shouldStop(responses: [response(correct: true), response(correct: true), response(correct: true)]))
        XCTAssertFalse(engine.shouldStop(responses: [response(correct: true), response(correct: false), response(correct: true)]))
        XCTAssertTrue(engine.shouldStop(responses: (0..<5).map { response(correct: $0.isMultiple(of: 2)) }))
    }

    private func response(correct: Bool) -> AssessmentResponse {
        let packageItem = AssessmentPackage.Item(
            knowledgeNodeID: UUID(),
            tier: .foundational,
            stem: UUID().uuidString,
            answerOptions: ["A", "B", "C", "D"],
            correctAnswerIndex: 0,
            reasoningPrompt: "why",
            reasoningOptions: ["1", "2", "3", "4"],
            correctReasoningIndex: 0,
            explanation: "explanation",
            misconceptionTags: [],
            sourceActivityIDs: []
        )
        let item = AssessmentItem(sessionID: UUID(), item: packageItem)
        return AssessmentResponse(
            item: item,
            selectedAnswerIndex: correct ? 0 : 1,
            selectedReasoningIndex: correct ? 0 : 1,
            usedAssistance: false
        )
    }
}
