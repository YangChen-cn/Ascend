import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class ArtifactCoveragePolicyTests: XCTestCase {
    func testSystematicExplanationBuildsEntryFoundationWithoutMemoryOrAutonomy() {
        let foundation = ArtifactCoveragePolicy.foundationFloor(for: .explanation, coverage: 0.85)

        XCTAssertGreaterThanOrEqual(foundation.composite, 20)
        XCTAssertLessThan(foundation.composite, 40)
        XCTAssertEqual(foundation.retention, 0)
        XCTAssertEqual(foundation.autonomy, 0)
    }

    func testBriefExposureStaysBelowEntryFoundation() {
        let foundation = ArtifactCoveragePolicy.foundationFloor(for: .exposure, coverage: 0.25)

        XCTAssertLessThan(foundation.composite, 20)
        XCTAssertEqual(foundation.retention, 0)
        XCTAssertEqual(foundation.autonomy, 0)
    }

    func testCoverageIsClampedAndLegacyFallbackIsStable() {
        XCTAssertEqual(ArtifactCoveragePolicy.normalized(-3, for: .explanation), 0.15)
        XCTAssertEqual(ArtifactCoveragePolicy.normalized(3, for: .explanation), 0.85)
        XCTAssertEqual(
            ArtifactCoveragePolicy.normalized(nil, for: .explanation),
            ArtifactCoveragePolicy.legacyCoverage(for: .explanation)
        )
    }

    func testLaterIncrementDoesNotLowerFoundationAndDuplicateHashDoesNotRescore() throws {
        let (container, appState, node, _) = try makeAppState()
        let first = makeArtifact(nodeID: node.id, kind: .explanation, coverage: 0.85, hash: "first")
        insert(first, into: container, appState: appState)
        let firstXP = appState.applyArtifactEvidence(first)
        let baseline = try XCTUnwrap(appState.mastery(for: node.id)).artifactVector

        let increment = makeArtifact(nodeID: node.id, kind: .exposure, coverage: 0.15, hash: "increment")
        insert(increment, into: container, appState: appState)
        _ = appState.applyArtifactEvidence(increment)
        let afterIncrement = try XCTUnwrap(appState.mastery(for: node.id)).artifactVector

        let duplicate = makeArtifact(nodeID: node.id, kind: .explanation, coverage: 0.85, hash: "first")
        insert(duplicate, into: container, appState: appState)
        XCTAssertEqual(appState.applyArtifactEvidence(duplicate), 0)

        XCTAssertGreaterThanOrEqual(afterIncrement.exposure, baseline.exposure)
        XCTAssertGreaterThanOrEqual(afterIncrement.understanding, baseline.understanding)
        XCTAssertGreaterThan(firstXP, 0)
    }

    func testHistoricalReplayPreservesXPAndDirectProjection() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ArtifactCoveragePolicyTests.\(UUID().uuidString)"))
        defer { defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "") }
        let container = PersistenceController.makeContainer(inMemory: true)
        let node = KnowledgeNode(name: "进程创建", domain: "嵌入式 Linux", isProvisional: false)
        let state = MasteryState(knowledgeNodeID: node.id, lifetimeXP: 503, peakComposite: 1)
        let estimate = MasteryEstimate(
            knowledgeNodeID: node.id,
            dimension: .autonomy,
            probability: 0.8,
            observationCount: 1,
            correctCount: 1,
            lastObservedAt: .now,
            modelVersion: MasteryEstimator.modelVersion
        )
        let evidence = makeArtifact(nodeID: node.id, kind: .explanation, coverage: nil, hash: "legacy")
        container.mainContext.insert(node)
        container.mainContext.insert(state)
        container.mainContext.insert(estimate)
        container.mainContext.insert(evidence)
        try container.mainContext.save()

        let appState = AppState(modelContainer: container, automationDefaults: defaults)
        defaults.removeObject(forKey: AppConstants.artifactCoverageModelVersionKey)
        XCTAssertTrue(try appState.reconcileArtifactCoverageModelIfNeeded())

        let replayed = try XCTUnwrap(appState.mastery(for: node.id))
        XCTAssertEqual(replayed.lifetimeXP, 503)
        XCTAssertGreaterThanOrEqual(replayed.artifactVector.composite, 20)
        XCTAssertEqual(replayed.vector.autonomy, 80, accuracy: 0.001)
        XCTAssertNotNil(try XCTUnwrap(appState.evidenceRecords.first).artifactCoverage)
        XCTAssertFalse(try appState.reconcileArtifactCoverageModelIfNeeded())
    }

    func testHistoricalReplayRepairsIncompleteStoreEvenWhenVersionWasAlreadyMarked() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ArtifactCoverageRepairTests.\(UUID().uuidString)"))
        defer { defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "") }
        let container = PersistenceController.makeContainer(inMemory: true)
        let node = KnowledgeNode(name: "管道", domain: "嵌入式 Linux", isProvisional: false)
        let state = MasteryState(
            knowledgeNodeID: node.id,
            vector: MasteryVector(exposure: 1, understanding: 1, practice: 1, retention: 0, autonomy: 0),
            lifetimeXP: 503,
            peakComposite: 17
        )
        let evidence = makeArtifact(nodeID: node.id, kind: .explanation, coverage: nil, hash: "interrupted-upgrade")
        container.mainContext.insert(node)
        container.mainContext.insert(state)
        container.mainContext.insert(evidence)
        try container.mainContext.save()

        let appState = AppState(modelContainer: container, automationDefaults: defaults)
        // 模拟一次中断升级：版本标记已写入，但新字段还停留在数据库默认值。
        let interruptedState = try XCTUnwrap(appState.mastery(for: node.id))
        interruptedState.artifactVector = .zero
        try XCTUnwrap(appState.evidenceRecords.first).artifactCoverage = nil
        try container.mainContext.save()
        defaults.set(ArtifactCoveragePolicy.modelVersion, forKey: AppConstants.artifactCoverageModelVersionKey)

        XCTAssertTrue(try appState.reconcileArtifactCoverageModelIfNeeded())

        let repaired = try XCTUnwrap(appState.mastery(for: node.id))
        XCTAssertGreaterThanOrEqual(repaired.artifactVector.composite, 20)
        XCTAssertEqual(repaired.lifetimeXP, 503, "资料回放不应重发或倒扣历史 XP")
        XCTAssertNotNil(try XCTUnwrap(appState.evidenceRecords.first).artifactCoverage)
        XCTAssertFalse(try appState.reconcileArtifactCoverageModelIfNeeded(), "资料字段已补齐后重放必须幂等")
    }

    func testAnalyzedEvidenceDecodesLegacyCoverageAndNormalizesNewCoverage() throws {
        let legacy = """
        {"id":"00000000-0000-0000-0000-000000000001","activityID":"00000000-0000-0000-0000-000000000002","knowledgeName":"进程","matchedNodeID":null,"matchConfidence":0.5,"kind":"explanation","difficulty":1,"independence":1,"confidence":0.8,"summary":"解释","rationale":"依据"}
        """
        let decoded = try JSONDecoder().decode(AnalyzedEvidence.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.coverage, ArtifactCoveragePolicy.legacyCoverage(for: .explanation))

        let normalized = AnalyzedEvidence(
            activityID: UUID(), knowledgeName: "进程", matchedNodeID: nil, matchConfidence: 0.5,
            kind: .explanation, difficulty: 1, independence: 1, confidence: 0.8,
            coverage: 4, summary: "解释", rationale: "依据"
        )
        XCTAssertEqual(normalized.coverage, 0.85)
    }

    private func makeAppState() throws -> (ModelContainer, AppState, KnowledgeNode, UserDefaults) {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ArtifactCoveragePolicyTests.\(UUID().uuidString)"))
        let container = PersistenceController.makeContainer(inMemory: true)
        let node = KnowledgeNode(name: "进程创建", domain: "嵌入式 Linux", isProvisional: false)
        container.mainContext.insert(node)
        container.mainContext.insert(MasteryState(knowledgeNodeID: node.id))
        try container.mainContext.save()
        return (container, AppState(modelContainer: container, automationDefaults: defaults), node, defaults)
    }

    private func makeArtifact(nodeID: UUID, kind: EvidenceKind, coverage: Double?, hash: String) -> EvidenceRecord {
        EvidenceRecord(
            activityID: UUID(), knowledgeNodeID: nodeID, kind: kind, timestamp: .now,
            summary: "资料", rationale: "资料覆盖", difficulty: 1, independence: 1,
            aiConfidence: 0.9, isVerified: true, fingerprint: "fingerprint-\(UUID().uuidString)",
            contentChangeHash: hash, origin: .artifact, verificationLevel: .artifactCandidate,
            artifactCoverage: coverage
        )
    }

    private func insert(_ evidence: EvidenceRecord, into container: ModelContainer, appState: AppState) {
        container.mainContext.insert(evidence)
        appState.evidenceRecords.append(evidence)
        appState.evidenceByID[evidence.id] = evidence
        appState.evidenceByNodeID[evidence.knowledgeNodeID, default: []].append(evidence)
    }
}
