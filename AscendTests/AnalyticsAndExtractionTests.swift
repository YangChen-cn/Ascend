import XCTest
@testable import Ascend

final class AnalyticsAndExtractionTests: XCTestCase {
    private let analyticsEngine = AnalyticsEngine()
    private let scoringEngine = ScoringEngine()

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
            scoringEngine: scoringEngine
        )

        XCTAssertEqual(snapshots.count, 1)
        let ios = snapshots[0]
        XCTAssertEqual(ios.name, "iOS")
        XCTAssertEqual(ios.knowledgeCount, 2)
        XCTAssertEqual(ios.xp, 500)
        XCTAssertEqual(ios.score, 70.0, accuracy: 0.001)
        XCTAssertEqual(ios.historicalScore, 70.0, accuracy: 0.001)
    }

    func testDomainRealmUsesHistoricalMasteryWhileReadinessUsesDecay() {
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
            scoringEngine: scoringEngine,
            now: now
        )[0]

        XCTAssertEqual(snapshot.historicalScore, 80, accuracy: 0.001)
        XCTAssertLessThan(snapshot.currentScore, snapshot.historicalScore)
        XCTAssertEqual(snapshot.realm, .connected)
        XCTAssertLessThan(snapshot.currentRealm.rawValue, snapshot.realm.rawValue)
        XCTAssertEqual(snapshot.xp, 8_000)
    }

    func testComputeForgettingProjectionsDetectsDecay() {
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
            scoringEngine: scoringEngine,
            now: .now
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
}
