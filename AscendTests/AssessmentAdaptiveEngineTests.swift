import XCTest
@testable import Ascend

final class AssessmentAdaptiveEngineTests: XCTestCase {
    private let engine = AssessmentAdaptiveEngine()

    func testReasoningUnlockRequiresCorrectAnswerButScoringKeepsFirstAttempt() {
        var gate = AssessmentAnswerGate()

        XCTAssertFalse(gate.submitAnswer(2, correctIndex: 1))
        XCTAssertEqual(gate.firstSelectedIndex, 2)
        XCTAssertFalse(gate.isReasoningUnlocked)

        XCTAssertTrue(gate.submitAnswer(1, correctIndex: 1))
        XCTAssertEqual(gate.firstSelectedIndex, 2, "答对后的重试不得覆盖首次错误表现")
        XCTAssertTrue(gate.isReasoningUnlocked)
    }

    func testStartingTierFollowsCurrentProbability() {
        XCTAssertEqual(engine.startingTier(probability: nil), .application)
        XCTAssertEqual(engine.startingTier(probability: 0.34), .foundational)
        XCTAssertEqual(engine.startingTier(probability: 0.35), .application)
        XCTAssertEqual(engine.startingTier(probability: 0.65), .transfer)
    }

    func testStopConditionAdaptive() {
        XCTAssertFalse(engine.shouldStop(responses: []))
        // 1 题完全正确独立作答 -> 立即结束
        XCTAssertTrue(engine.shouldStop(responses: [response(correct: true)]))
        // 1 题错误 -> 继续
        XCTAssertFalse(engine.shouldStop(responses: [response(correct: false)]))
        // 2 题一致 -> 结束
        XCTAssertTrue(engine.shouldStop(responses: [response(correct: false), response(correct: false)]))
        XCTAssertTrue(engine.shouldStop(responses: [response(correct: true), response(correct: true)]))
        // 2 题不一致 -> 需继续到第 3 题
        XCTAssertFalse(engine.shouldStop(responses: [response(correct: false), response(correct: true)]))
        // 3 题上限 -> 结束
        XCTAssertTrue(engine.shouldStop(responses: [response(correct: false), response(correct: true), response(correct: false)]))
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
