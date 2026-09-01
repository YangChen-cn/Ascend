import XCTest
@testable import Ascend

final class AnalyticsAndExtractionTests: XCTestCase {
    private let analyticsEngine = AnalyticsEngine()

    func testExtractJSONStripsThinkTags() {
        let raw = """
        <think>
        I need to analyze this Git commit.
        The user implemented actor-based concurrency.
        The knowledge point is Swift Concurrency.
        </think>
        ```json
        {
          "sessionSummary": "测试摘要",
          "evidence": [],
          "nodeSuggestions": [],
          "edgeSuggestions": [],
          "challengeSuggestion": null
        }
        ```
        """
        let extracted = OpenAICompatibleClient.extractJSON(raw)
        XCTAssertFalse(extracted.contains("<think>"))
        XCTAssertFalse(extracted.contains("</think>"))
        XCTAssertTrue(extracted.hasPrefix("{"))
        XCTAssertTrue(extracted.hasSuffix("}"))
    }

    func testExtractJSONWithPreambleAndPostamble() {
        let raw = """
        Here is the JSON result:
        {
          "sessionSummary": "OK",
          "evidence": [],
          "nodeSuggestions": [],
          "edgeSuggestions": [],
          "challengeSuggestion": null
        }
        Hope this helps!
        """
        let extracted = OpenAICompatibleClient.extractJSON(raw)
        XCTAssertTrue(extracted.hasPrefix("{"))
        XCTAssertTrue(extracted.hasSuffix("}"))
        XCTAssertFalse(extracted.contains("Here is the JSON result"))
    }

    func testComputeDomainProgressAggregatesAccurately() {
        let node1 = KnowledgeNode(name: "SwiftData", domain: "iOS", isProvisional: false)
        let state1 = MasteryState(knowledgeNodeID: node1.id, vector: MasteryVector(exposure: 80, understanding: 80, practice: 80, retention: 80, autonomy: 80), lifetimeXP: 300)

        let node2 = KnowledgeNode(name: "SwiftUI", domain: "iOS", isProvisional: false)
        let state2 = MasteryState(knowledgeNodeID: node2.id, vector: MasteryVector(exposure: 60, understanding: 60, practice: 60, retention: 60, autonomy: 60), lifetimeXP: 200)

        let snapshots = analyticsEngine.computeDomainProgress(
            nodes: [node1, node2],
            masteryStates: [state1, state2],
            currentRetentionByNodeID: [node1.id: 80, node2.id: 60]
        )

        XCTAssertEqual(snapshots.count, 1)
        let ios = snapshots[0]
        XCTAssertEqual(ios.name, "iOS")
        XCTAssertEqual(ios.knowledgeCount, 2)
        XCTAssertEqual(ios.xp, 500)
        XCTAssertEqual(ios.score, 70.0, accuracy: 0.001)
        XCTAssertEqual(ios.historicalScore, 70.0, accuracy: 0.001)
        XCTAssertEqual(ios.masterySampleCount, 2)
    }

    func testDomainProgressUsesHighestTenMasteryStatesRatherThanDilutingWithExpansionNodes() {
        let nodes = (0..<12).map { index in
            KnowledgeNode(name: "知识 \(index)", domain: "Linux", isProvisional: false)
        }
        let states = nodes.enumerated().map { index, node in
            MasteryState(
                knowledgeNodeID: node.id,
                vector: MasteryVector(
                    exposure: index < 10 ? 30 : 0,
                    understanding: index < 10 ? 30 : 0,
                    practice: index < 10 ? 30 : 0,
                    retention: index < 10 ? 30 : 0,
                    autonomy: index < 10 ? 30 : 0
                ),
                lifetimeXP: index < 10 ? 30 : 0
            )
        }

        let snapshot = analyticsEngine.computeDomainProgress(
            nodes: nodes,
            masteryStates: states,
            currentRetentionByNodeID: [:]
        )[0]

        XCTAssertEqual(snapshot.knowledgeCount, 12)
        XCTAssertEqual(snapshot.masterySampleCount, 10)
        XCTAssertEqual(snapshot.historicalScore, 30, accuracy: 0.001)
        XCTAssertEqual(snapshot.xp, 300)
        XCTAssertEqual(snapshot.realm, .entry)
    }

    func testDomainRealmUsesHistoricalMasteryWhileReadinessUsesFSRSRetention() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let node = KnowledgeNode(name: "进程", domain: "Linux", isProvisional: false)
        let state = MasteryState(
            knowledgeNodeID: node.id,
            vector: MasteryVector(exposure: 80, understanding: 80, practice: 80, retention: 80, autonomy: 80),
            stabilityDays: 3,
            lastEvidenceAt: now.addingTimeInterval(-30 * 86_400),
            lifetimeXP: 8_000,
            highestStage: .connected
        )

        let snapshot = analyticsEngine.computeDomainProgress(
            nodes: [node],
            masteryStates: [state],
            currentRetentionByNodeID: [node.id: 20]
        )[0]

        XCTAssertEqual(snapshot.historicalScore, 80, accuracy: 0.001)
        XCTAssertLessThan(snapshot.currentScore, snapshot.historicalScore)
        XCTAssertEqual(snapshot.realm, .connected)
        XCTAssertLessThan(snapshot.currentRealm.rawValue, snapshot.realm.rawValue)
        XCTAssertEqual(snapshot.xp, 8_000)
    }

    func testComputeForgettingProjectionsUsesProjectedMemoryRetention() {
        let node = KnowledgeNode(name: "Algorithm", domain: "CS", isProvisional: false)
        let state = MasteryState(
            knowledgeNodeID: node.id,
            vector: MasteryVector(exposure: 80, understanding: 80, practice: 80, retention: 80, autonomy: 80),
            stabilityDays: 3,
            lastEvidenceAt: Date.now.addingTimeInterval(-10 * 86_400)
        )

        let projections = analyticsEngine.computeForgettingProjections(
            nodes: [node],
            masteryStates: [state],
            currentRetentionByNodeID: [node.id: 25]
        )

        XCTAssertFalse(projections.isEmpty)
        XCTAssertEqual(projections.first?.node.name, "Algorithm")
        XCTAssertGreaterThan(projections.first?.scoreLoss ?? 0, 0)
    }

    func testTrajectoryPointsComeOnlyFromLedgerEntries() {
        let nodeID = UUID()
        let first = ScoreLedgerEntry(
            evidenceID: UUID(),
            knowledgeNodeID: nodeID,
            timestamp: Date(timeIntervalSince1970: 100),
            previousComposite: 0,
            newComposite: 4.5,
            xpAwarded: 45,
            reason: "真实笔记证据"
        )
        let second = ScoreLedgerEntry(
            evidenceID: UUID(),
            knowledgeNodeID: nodeID,
            timestamp: Date(timeIntervalSince1970: 200),
            previousComposite: 4.5,
            newComposite: 9,
            xpAwarded: 45,
            reason: "真实项目证据"
        )

        let points = TrajectoryPoint.make(from: [second, first])

        XCTAssertEqual(points.map(\.score), [0, 4.5, 9])
        XCTAssertEqual(points.last?.reason, "真实项目证据")
        XCTAssertTrue(TrajectoryPoint.make(from: []).isEmpty)
    }

    func testMasteryVectorAverageAndClamping() {
        let vector1 = MasteryVector(exposure: 120, understanding: 80, practice: 70, retention: -10, autonomy: 50).clamped()
        XCTAssertEqual(vector1.exposure, 100.0)
        XCTAssertEqual(vector1.retention, 0.0)
        XCTAssertEqual(vector1.understanding, 80.0)

        let vector2 = MasteryVector(exposure: 60, understanding: 40, practice: 30, retention: 20, autonomy: 10)
        let composite1 = vector1.composite
        let composite2 = vector2.composite
        XCTAssertGreaterThan(composite1, composite2)
    }
}
