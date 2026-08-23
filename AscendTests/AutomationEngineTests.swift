import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class AutomationEngineTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        container = PersistenceController.makeContainer(inMemory: true)
        suiteName = "AutomationEngineTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        appState = AppState(modelContainer: container, automationDefaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        suiteName = nil
        defaults = nil
        appState = nil
        container = nil
    }

    func testAutomaticCollectionPreferencePersistsAcrossAppStateInstances() {
        appState.isCollecting = false
        XCTAssertFalse(AutomationPreferences.current(defaults: defaults).collectionEnabled)

        let restored = AppState(modelContainer: container, automationDefaults: defaults)
        XCTAssertFalse(restored.isCollecting)

        restored.isCollecting = true
        XCTAssertTrue(AutomationPreferences.current(defaults: defaults).collectionEnabled)
    }

    func testCollectionSchedulerNeverOverlapsScans() async throws {
        let scheduler = ActivityCollectionScheduler()
        let probe = CollectionProbe()
        await scheduler.start(interval: .milliseconds(5)) {
            await probe.scan()
        }

        try await Task.sleep(for: .milliseconds(120))
        await scheduler.stop()

        XCTAssertEqual(probe.maximumConcurrentScans, 1)
        XCTAssertGreaterThanOrEqual(probe.scanCount, 2)
    }

    func testReviewPlanBecomesDueAndVerifiedReviewCompletesIt() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let node = KnowledgeNode(name: "fork", domain: "嵌入式 Linux")
        let plan = ReviewPlan(
            knowledgeNodeID: node.id,
            createdAt: now.addingTimeInterval(-86_400),
            scheduledAt: now.addingTimeInterval(-60),
            reason: "巩固进程创建"
        )
        container.mainContext.insert(node)
        container.mainContext.insert(plan)
        try? container.mainContext.save()
        appState.reload()

        appState.runTriggerEngine(now: now)
        XCTAssertEqual(plan.status, "due")

        let evidence = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: node.id,
            kind: .review,
            timestamp: now.addingTimeInterval(1),
            summary: "复习 fork",
            rationale: "真实复习",
            difficulty: 1,
            independence: 0.9,
            aiConfidence: 0.9,
            isVerified: true,
            fingerprint: "review-plan-completion"
        )
        container.mainContext.insert(evidence)
        try? container.mainContext.save()
        appState.reload()
        appState.runTriggerEngine(now: now.addingTimeInterval(2))

        XCTAssertEqual(plan.status, "completed")
    }

    func testChallengeSuggestionLinksToRealKnowledgeNode() throws {
        let node = KnowledgeNode(name: "fork 与 pipe", domain: "嵌入式 Linux")
        let state = MasteryState(knowledgeNodeID: node.id)
        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .manual,
            timestamp: .now,
            fingerprint: "challenge-link-activity",
            title: "fork pipe 实践",
            sourceLocator: "manual:challenge",
            summary: "实践",
            excerpt: "实践"
        )
        let run = AnalysisRun(endpointProfileID: nil, modelID: "mock", activityCount: 1)
        container.mainContext.insert(node)
        container.mainContext.insert(state)
        container.mainContext.insert(activity)
        container.mainContext.insert(run)
        try container.mainContext.save()
        appState.reload()

        let envelope = AnalysisEnvelope(
            sessionSummary: "完成进程通信实践",
            evidence: [
                AnalyzedEvidence(
                    id: UUID(),
                    activityID: activity.id,
                    knowledgeName: node.name,
                    matchedNodeID: node.id,
                    matchConfidence: 0.95,
                    kind: .project,
                    difficulty: 1,
                    independence: 0.9,
                    confidence: 0.9,
                    summary: "fork 与 pipe 实践",
                    rationale: "真实项目"
                )
            ],
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: ChallengeSuggestion(
                title: "独立完成进程通信",
                description: "再次完成 fork 与 pipe 实践",
                estimatedMinutes: 45,
                knowledgeNames: [node.name],
                requirement: ChallengeRequirement(),
                rewardXP: 50
            )
        )

        try appState.apply(envelope: envelope, to: [activity], analysisRun: run)

        XCTAssertEqual(appState.challenges.count, 1)
        XCTAssertEqual(appState.challenges[0].knowledgeNodeIDs, [node.id])
        XCTAssertEqual(appState.challengeAutomationStates.first?.challengeID, appState.challenges[0].id)
    }

    func testChallengeCompletesOnlyWhenStructuredConditionsAreSatisfied() throws {
        let now = Date(timeIntervalSince1970: 3_000_000)
        let node = KnowledgeNode(name: "pipe", domain: "嵌入式 Linux")
        let mastery = MasteryState(
            knowledgeNodeID: node.id,
            vector: MasteryVector(exposure: 50, understanding: 50, practice: 50, retention: 50, autonomy: 50)
        )
        let challenge = Challenge(
            title: "pipe 实践",
            challengeDescription: "独立完成管道通信",
            estimatedMinutes: 30,
            knowledgeNodeIDs: [node.id],
            requirements: [],
            rewardXP: 40,
            status: "in_progress",
            createdAt: now.addingTimeInterval(-100)
        )
        let automation = ChallengeAutomationState(
            challengeID: challenge.id,
            requirement: ChallengeRequirement(
                minimumEvidenceKind: .project,
                minimumIndependence: 0.8,
                minimumConfidence: 0.8,
                minimumMastery: 40,
                requiredEvidenceCount: 1
            ),
            acceptedAt: now.addingTimeInterval(-50)
        )
        let weakEvidence = makeEvidence(
            nodeID: node.id,
            timestamp: now,
            independence: 0.6,
            fingerprint: "weak-challenge-evidence"
        )
        container.mainContext.insert(node)
        container.mainContext.insert(mastery)
        container.mainContext.insert(challenge)
        container.mainContext.insert(automation)
        container.mainContext.insert(weakEvidence)
        try container.mainContext.save()
        appState.reload()

        appState.runTriggerEngine(now: now.addingTimeInterval(1))
        XCTAssertEqual(challenge.status, "in_progress")

        let qualifyingEvidence = makeEvidence(
            nodeID: node.id,
            timestamp: now.addingTimeInterval(2),
            independence: 0.9,
            fingerprint: "qualifying-challenge-evidence"
        )
        container.mainContext.insert(qualifyingEvidence)
        try container.mainContext.save()
        appState.reload()
        let knowledgeXPBefore = appState.totalXP
        appState.runTriggerEngine(now: now.addingTimeInterval(3))

        XCTAssertEqual(challenge.status, "completed")
        XCTAssertNotNil(challenge.completedAt)
        XCTAssertEqual(appState.challengeXP, 40)
        XCTAssertEqual(appState.totalXP, knowledgeXPBefore)
    }

    func testTriggerEngineIsIdempotentForRetentionReviewPlans() throws {
        let now = Date(timeIntervalSince1970: 4_000_000)
        let node = KnowledgeNode(name: "进程调度", domain: "Linux")
        let mastery = MasteryState(
            knowledgeNodeID: node.id,
            vector: MasteryVector(exposure: 80, understanding: 80, practice: 80, retention: 80, autonomy: 80),
            stabilityDays: 3,
            lastEvidenceAt: now.addingTimeInterval(-30 * 86_400)
        )
        container.mainContext.insert(node)
        container.mainContext.insert(mastery)
        try container.mainContext.save()
        appState.reload()

        appState.runTriggerEngine(now: now)
        let firstCount = appState.reviewPlans.count
        appState.runTriggerEngine(now: now)

        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(appState.reviewPlans.count, 1)
        XCTAssertEqual(appState.automationReceipts.count, 1)
    }

    func testMultipleBatchSummariesUpsertOneDailyDigestContainingAllResults() throws {
        let now = Date(timeIntervalSince1970: 5_000_000)
        let firstRunID = UUID()
        let secondRunID = UUID()
        container.mainContext.insert(
            AnalysisBatchSummary(analysisRunID: firstRunID, date: now, summary: "学习了 fork 进程创建")
        )
        container.mainContext.insert(
            AnalysisBatchSummary(analysisRunID: secondRunID, date: now.addingTimeInterval(60), summary: "实践了 pipe 进程通信")
        )
        try container.mainContext.save()

        _ = try appState.upsertDailyDigest(date: now, batchSummaries: [])
        _ = try appState.upsertDailyDigest(date: now.addingTimeInterval(120), batchSummaries: [])

        XCTAssertEqual(appState.digests.count, 1)
        XCTAssertTrue(appState.digests[0].summary.contains("fork 进程创建"))
        XCTAssertTrue(appState.digests[0].summary.contains("pipe 进程通信"))
    }

    private func makeEvidence(
        nodeID: UUID,
        timestamp: Date,
        independence: Double,
        fingerprint: String
    ) -> EvidenceRecord {
        EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: nodeID,
            kind: .project,
            timestamp: timestamp,
            summary: "真实项目实践",
            rationale: "测试结构化条件",
            difficulty: 1,
            independence: independence,
            aiConfidence: 0.9,
            isVerified: true,
            fingerprint: fingerprint
        )
    }
}

@MainActor
private final class CollectionProbe {
    private(set) var scanCount = 0
    private(set) var maximumConcurrentScans = 0
    private var concurrentScans = 0

    func scan() async {
        concurrentScans += 1
        scanCount += 1
        maximumConcurrentScans = max(maximumConcurrentScans, concurrentScans)
        try? await Task.sleep(for: .milliseconds(30))
        concurrentScans -= 1
    }
}
