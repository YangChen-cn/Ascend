import XCTest
@testable import Ascend

final class LearningRecommendationEngineTests: XCTestCase {
    private let engine = LearningRecommendationEngine()
    private let now = Date(timeIntervalSince1970: 2_200_000_000)

    func testPrioritizesReviewThenPracticeAndChallengeWithoutStableNoise() {
        let reviewNode = UUID()
        let practiceNode = UUID()
        let challengeNode = UUID()
        let stableNode = UUID()
        let challengeID = UUID()
        let recommendations = engine.recommendations(
            knowledge: [
                snapshot(
                    id: reviewNode,
                    name: "fork",
                    mastery: vector(understanding: 70, practice: 65, autonomy: 60),
                    retrievability: 0.63,
                    reviewDate: now.addingTimeInterval(-86_400)
                ),
                snapshot(
                    id: practiceNode,
                    name: "socket",
                    mastery: vector(understanding: 75, practice: 41, autonomy: 24)
                ),
                snapshot(
                    id: challengeNode,
                    name: "pipe",
                    mastery: MasteryVector(exposure: 60, understanding: 60, practice: 60, retention: 60, autonomy: 60)
                ),
                snapshot(
                    id: stableNode,
                    name: "stable",
                    mastery: MasteryVector(exposure: 70, understanding: 70, practice: 70, retention: 70, autonomy: 70),
                    retrievability: 0.92
                )
            ],
            challenges: [
                RecommendationChallengeSnapshot(
                    id: challengeID,
                    title: "完成 pipe 实践",
                    knowledgeNodeIDs: [challengeNode],
                    status: "available"
                )
            ],
            now: now
        )

        XCTAssertEqual(recommendations.map(\.knowledgeNodeID), [reviewNode, practiceNode, challengeNode])
        XCTAssertEqual(recommendations.map(\.type), [.review, .practice, .challenge])
        XCTAssertTrue(recommendations[0].reason.contains("63"))
        XCTAssertTrue(recommendations[1].reason.contains("实践"))
        XCTAssertFalse(recommendations.contains { $0.knowledgeNodeID == stableNode })
    }

    func testRecommendationOrderingIsStable() {
        let knowledge = [
            snapshot(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "B", mastery: vector(understanding: 70, practice: 40, autonomy: 40)),
            snapshot(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "A", mastery: vector(understanding: 70, practice: 40, autonomy: 40))
        ]

        let first = engine.recommendations(knowledge: knowledge, challenges: [], now: now)
        let second = engine.recommendations(knowledge: knowledge.reversed(), challenges: [], now: now)

        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testContinueRequiresRealRecentMomentum() {
        let active = snapshot(
            id: UUID(),
            name: "进程",
            mastery: MasteryVector(exposure: 30, understanding: 30, practice: 30, retention: 30, autonomy: 30),
            recentEvidenceCount: 3,
            lastEvidenceAt: now.addingTimeInterval(-3_600)
        )
        let recommendation = engine.recommendations(knowledge: [active], challenges: [], now: now).first

        XCTAssertEqual(recommendation?.type, .continue)
        XCTAssertTrue(recommendation?.reason.contains("3 条") == true)
    }

    func testPrerequisiteProviderCanBlockRecommendationWithoutChangingEngine() {
        let nodeID = UUID()
        let candidate = snapshot(
            id: nodeID,
            name: "epoll",
            mastery: .zero
        )

        let recommendations = engine.recommendations(
            knowledge: [candidate],
            challenges: [],
            now: now,
            prerequisiteProvider: BlockedPrerequisiteProvider(blockedNodeID: nodeID)
        )

        XCTAssertTrue(recommendations.isEmpty, "先导受阻且未学习的知识点不得推荐探索")
    }

    private func snapshot(
        id: UUID,
        name: String,
        mastery: MasteryVector,
        retrievability: Double? = nil,
        reviewDate: Date? = nil,
        recentEvidenceCount: Int = 0,
        lastEvidenceAt: Date? = nil
    ) -> RecommendationKnowledgeSnapshot {
        RecommendationKnowledgeSnapshot(
            id: id,
            name: name,
            mastery: mastery,
            retrievability: retrievability,
            activeReviewPlanID: reviewDate == nil ? nil : UUID(),
            reviewScheduledAt: reviewDate,
            recentEvidenceCount: recentEvidenceCount,
            lastEvidenceAt: lastEvidenceAt
        )
    }

    private func vector(understanding: Double, practice: Double, autonomy: Double) -> MasteryVector {
        MasteryVector(
            exposure: understanding,
            understanding: understanding,
            practice: practice,
            retention: understanding,
            autonomy: autonomy
        )
    }
}

private struct BlockedPrerequisiteProvider: PrerequisiteReadinessProviding {
    let blockedNodeID: UUID

    func readiness(for knowledgeNodeID: UUID) -> PrerequisiteReadiness {
        knowledgeNodeID == blockedNodeID ? .blocked(reason: "前置知识尚未就绪") : .ready
    }
}
