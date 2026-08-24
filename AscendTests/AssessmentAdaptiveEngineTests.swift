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

    func testNextItemHardStopsAtThreeResponsesEvenWithUncoveredNodes() {
        let node1 = UUID()
        let node2 = UUID()
        let node3 = UUID()
        let node4 = UUID()
        let node5 = UUID()

        var items: [AssessmentItem] = []
        for n in [node1, node2, node3, node4, node5] {
            let pkgItem = AssessmentPackage.Item(
                knowledgeNodeID: n,
                tier: .application,
                stem: "Stem",
                answerOptions: ["A", "B", "C", "D"],
                correctAnswerIndex: 0,
                reasoningPrompt: "R",
                reasoningOptions: ["1", "2", "3", "4"],
                correctReasoningIndex: 0,
                explanation: "Exp",
                misconceptionTags: [],
                sourceActivityIDs: []
            )
            items.append(AssessmentItem(sessionID: UUID(), item: pkgItem))
        }

        let resp1 = response(correct: false, item: items[0])
        let resp2 = response(correct: true, item: items[1])
        let resp3 = response(correct: false, item: items[2])

        let next = engine.nextItem(
            from: items,
            presentedItemIDs: [items[0].id, items[1].id, items[2].id],
            responses: [resp1, resp2, resp3],
            initialProbability: 0.5
        )
        XCTAssertNil(next, "即使题包包含 5 个知识点，达到 3 个 response 后 nextItem 也必须为 nil")
    }

    private func response(correct: Bool, item: AssessmentItem? = nil) -> AssessmentResponse {
        let assessmentItem = item ?? {
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
            return AssessmentItem(sessionID: UUID(), item: packageItem)
        }()
        return AssessmentResponse(
            item: assessmentItem,
            selectedAnswerIndex: correct ? 0 : 1,
            selectedReasoningIndex: correct ? 0 : 1,
            usedAssistance: false
        )
    }
}
