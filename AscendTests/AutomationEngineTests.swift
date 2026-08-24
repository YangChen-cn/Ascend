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

        try await Task.sleep(for: .milliseconds(25))
        await scheduler.stop()

        XCTAssertEqual(probe.maximumConcurrentScans, 1)
        XCTAssertGreaterThanOrEqual(probe.scanCount, 2)
    }

    func testAutomationTickMarksReviewDueWithoutAutomaticAIAndDoesNotDuplicateNotificationReceipt() async throws {
        let now = Date(timeIntervalSince1970: 1_500_000)
        let node = KnowledgeNode(name: "进程", domain: "Linux")
        let plan = ReviewPlan(
            knowledgeNodeID: node.id,
            createdAt: now.addingTimeInterval(-3_600),
            scheduledAt: now.addingTimeInterval(-60),
            reason: "定时温故"
        )
        container.mainContext.insert(node)
        container.mainContext.insert(plan)
        try container.mainContext.save()
        appState.reload()
        appState.automaticAnalysisPolicy = .off

        let scheduler = AutomationTickScheduler()
        await scheduler.start(interval: .milliseconds(5)) { [weak appState] in
            await appState?.runAutomationTick(now: now)
        }
        try await Task.sleep(for: .milliseconds(15))
        await scheduler.stop()

        XCTAssertEqual(plan.status, "due")
    }

    func testDailyAnalysisRunsOnlyAfterConfiguredTimeAndOnlyOncePerDay() async {
        let scheduler = AnalysisScheduler()
        let probe = AnalysisProbe()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let before = calendar.date(bySettingHour: 21, minute: 29, second: 0, of: day)!
        let after = calendar.date(bySettingHour: 21, minute: 31, second: 0, of: day)!

        let beforeResult = await scheduler.runIfNeeded(
            policy: .daily,
            pendingCount: 3,
            threshold: 10,
            dailyHour: 21,
            dailyMinute: 30,
            lastRunAt: nil,
            now: before,
            calendar: calendar
        ) { await probe.run() }
        XCTAssertFalse(beforeResult)
        XCTAssertEqual(probe.runCount, 0)

        let afterResult = await scheduler.runIfNeeded(
            policy: .daily,
            pendingCount: 3,
            threshold: 10,
            dailyHour: 21,
            dailyMinute: 30,
            lastRunAt: nil,
            now: after,
            calendar: calendar
        ) { await probe.run() }
        XCTAssertTrue(afterResult)

        let repeatedResult = await scheduler.runIfNeeded(
            policy: .daily,
            pendingCount: 3,
            threshold: 10,
            dailyHour: 21,
            dailyMinute: 30,
            lastRunAt: after,
            now: after.addingTimeInterval(60),
            calendar: calendar
        ) { await probe.run() }
        XCTAssertFalse(repeatedResult)
        XCTAssertEqual(probe.runCount, 1)
    }

    func testThresholdAnalysisStillRunsBeforeDailyScheduledTime() async {
        let scheduler = AnalysisScheduler()
        let probe = AnalysisProbe()
        let didRun = await scheduler.runIfNeeded(
            policy: .pendingThreshold,
            pendingCount: 10,
            threshold: 10,
            dailyHour: 21,
            dailyMinute: 30,
            lastRunAt: .now,
            now: .now,
            calendar: .current
        ) { await probe.run() }

        XCTAssertTrue(didRun)
        XCTAssertEqual(probe.runCount, 1)
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

        XCTAssertThrowsError(try appState.recordReviewGrade(for: node.id, grade: .good, at: now.addingTimeInterval(1)))
        XCTAssertEqual(plan.status, "due")
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
        for dimension in MasteryDimension.allCases {
            container.mainContext.insert(
                MasteryEstimate(
                    knowledgeNodeID: node.id,
                    dimension: dimension,
                    probability: 0.50,
                    modelVersion: MasteryEstimator.modelVersion
                )
            )
        }
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

    func testMultiNodeChallengeRequiresQualifyingEvidenceForEveryTargetNode() throws {
        let now = Date(timeIntervalSince1970: 3_500_000)
        let fork = KnowledgeNode(name: "fork", domain: "Linux")
        let pipe = KnowledgeNode(name: "pipe", domain: "Linux")
        let challenge = Challenge(
            title: "进程通信实践",
            challengeDescription: "同时验证 fork 与 pipe",
            estimatedMinutes: 30,
            knowledgeNodeIDs: [fork.id, pipe.id],
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
                minimumMastery: 0,
                requiredEvidenceCount: 1
            ),
            acceptedAt: now.addingTimeInterval(-50)
        )
        container.mainContext.insert(fork)
        container.mainContext.insert(pipe)
        container.mainContext.insert(MasteryState(knowledgeNodeID: fork.id))
        container.mainContext.insert(MasteryState(knowledgeNodeID: pipe.id))
        container.mainContext.insert(challenge)
        container.mainContext.insert(automation)
        container.mainContext.insert(
            makeEvidence(
                nodeID: fork.id,
                timestamp: now,
                independence: 0.9,
                fingerprint: "fork-only"
            )
        )
        try container.mainContext.save()
        appState.reload()

        appState.runTriggerEngine(now: now.addingTimeInterval(1))
        XCTAssertEqual(challenge.status, "in_progress")

        container.mainContext.insert(
            makeEvidence(
                nodeID: pipe.id,
                timestamp: now.addingTimeInterval(2),
                independence: 0.9,
                fingerprint: "pipe-too"
            )
        )
        try container.mainContext.save()
        appState.reload()
        appState.runTriggerEngine(now: now.addingTimeInterval(3))

        XCTAssertEqual(challenge.status, "completed")
        XCTAssertEqual(appState.challengeXP, 40)
        XCTAssertEqual(appState.totalXP, 0)
    }

    func testChallengeDoesNotCountDuplicateProvenanceAsTwoEvidenceItems() {
        let acceptedAt = Date(timeIntervalSince1970: 3_700_000)
        let nodeID = UUID()
        let canonicalKey = "content:same-change:\(nodeID.uuidString)"
        let evidence = [
            ChallengeEvidenceSnapshot(
                id: UUID(),
                knowledgeNodeID: nodeID,
                kind: .project,
                timestamp: acceptedAt.addingTimeInterval(10),
                independence: 0.9,
                confidence: 0.9,
                isVerified: true,
                canonicalKey: canonicalKey
            ),
            ChallengeEvidenceSnapshot(
                id: UUID(),
                knowledgeNodeID: nodeID,
                kind: .project,
                timestamp: acceptedAt.addingTimeInterval(20),
                independence: 0.9,
                confidence: 0.9,
                isVerified: true,
                canonicalKey: canonicalKey
            )
        ]

        let evaluation = ChallengeEvaluator().evaluate(
            targetNodeIDs: [nodeID],
            requirement: ChallengeRequirement(
                minimumEvidenceKind: .project,
                minimumIndependence: 0.8,
                minimumConfidence: 0.8,
                minimumMastery: 0,
                requiredEvidenceCount: 2
            ),
            acceptedAt: acceptedAt,
            currentMasteryByNodeID: [nodeID: 0],
            evidence: evidence
        )

        XCTAssertFalse(evaluation.isCompleted)
        XCTAssertEqual(evaluation.matchedEvidenceIDs.count, 1)
    }

    func testChallengeIgnoresLaterProvenanceOfContentThatPredatesAcceptance() {
        let acceptedAt = Date(timeIntervalSince1970: 3_750_000)
        let nodeID = UUID()
        let canonicalKey = "content:preaccepted-change:\(nodeID.uuidString)"
        let evidence = [
            ChallengeEvidenceSnapshot(
                id: UUID(),
                knowledgeNodeID: nodeID,
                kind: .project,
                timestamp: acceptedAt.addingTimeInterval(-30),
                independence: 0.9,
                confidence: 0.9,
                isVerified: true,
                canonicalKey: canonicalKey
            ),
            ChallengeEvidenceSnapshot(
                id: UUID(),
                knowledgeNodeID: nodeID,
                kind: .project,
                timestamp: acceptedAt.addingTimeInterval(30),
                independence: 0.9,
                confidence: 0.9,
                isVerified: true,
                canonicalKey: canonicalKey
            )
        ]

        let evaluation = ChallengeEvaluator().evaluate(
            targetNodeIDs: [nodeID],
            requirement: ChallengeRequirement(
                minimumEvidenceKind: .project,
                minimumIndependence: 0.8,
                minimumConfidence: 0.8,
                minimumMastery: 0,
                requiredEvidenceCount: 1
            ),
            acceptedAt: acceptedAt,
            currentMasteryByNodeID: [nodeID: 0],
            evidence: evidence
        )

        XCTAssertFalse(evaluation.isCompleted)
        XCTAssertTrue(evaluation.matchedEvidenceIDs.isEmpty)
    }

    func testReviewPlanIgnoresLaterProvenanceOfContentThatPredatesPlan() {
        let nodeID = UUID()
        let planCreatedAt = Date(timeIntervalSince1970: 3_800_000)
        let plan = ReviewPlanTriggerSnapshot(
            id: UUID(),
            knowledgeNodeID: nodeID,
            createdAt: planCreatedAt,
            scheduledAt: planCreatedAt.addingTimeInterval(60),
            status: "scheduled"
        )
        let canonicalKey = "content:already-learned:\(nodeID.uuidString)"
        let evidence = [
            ChallengeEvidenceSnapshot(
                id: UUID(),
                knowledgeNodeID: nodeID,
                kind: .project,
                timestamp: planCreatedAt.addingTimeInterval(-60),
                independence: 0.9,
                confidence: 0.9,
                isVerified: true,
                canonicalKey: canonicalKey
            ),
            ChallengeEvidenceSnapshot(
                id: UUID(),
                knowledgeNodeID: nodeID,
                kind: .review,
                timestamp: planCreatedAt.addingTimeInterval(30),
                independence: 0.9,
                confidence: 0.9,
                isVerified: true,
                canonicalKey: canonicalKey
            )
        ]

        let actions = TriggerEngine().reviewPlanActions(
            memory: [],
            plans: [plan],
            evidence: evidence,
            memoryReviewCanonicalKeys: [],
            now: planCreatedAt.addingTimeInterval(30)
        )

        XCTAssertTrue(actions.isEmpty)
    }

    func testTriggerEngineIsIdempotentForFSRSReviewPlans() throws {
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
        container.mainContext.insert(
            MemoryState(
                knowledgeNodeID: node.id,
                difficulty: 5,
                stability: 3,
                retrievability: 0.6,
                lastReviewAt: now.addingTimeInterval(-3 * 86_400),
                nextReviewAt: now,
                scheduledDays: 3,
                reps: 1,
                learningState: .review
            )
        )
        try container.mainContext.save()
        appState.reload()

        appState.runTriggerEngine(now: now)
        let firstCount = appState.reviewPlans.count
        appState.runTriggerEngine(now: now)

        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(appState.reviewPlans.count, 1)
    }

    func testMultipleBatchSummariesUpsertOneDailyDigestContainingAllResults() throws {
        let now = Date(timeIntervalSince1970: 5_000_000)
        let firstRunID = UUID()
        let secondRunID = UUID()
        let firstSummary = AnalysisBatchSummary(
            analysisRunID: firstRunID,
            date: now,
            summary: "学习了 fork 进程创建"
        )
        let secondSummary = AnalysisBatchSummary(
            analysisRunID: secondRunID,
            date: now.addingTimeInterval(60),
            summary: "实践了 pipe 进程通信"
        )
        container.mainContext.insert(firstSummary)
        container.mainContext.insert(secondSummary)
        container.mainContext.insert(
            AnalysisBatchActivityLink(
                activityID: UUID(),
                batchSummaryID: firstSummary.id,
                activityDate: now
            )
        )
        container.mainContext.insert(
            AnalysisBatchActivityLink(
                activityID: UUID(),
                batchSummaryID: secondSummary.id,
                activityDate: now
            )
        )
        try container.mainContext.save()

        _ = try appState.upsertDailyDigest(date: now, batchSummaries: [])
        _ = try appState.upsertDailyDigest(date: now.addingTimeInterval(120), batchSummaries: [])

        XCTAssertEqual(appState.digests.count, 1)
        XCTAssertTrue(appState.digests[0].summary.contains("fork 进程创建"))
        XCTAssertTrue(appState.digests[0].summary.contains("pipe 进程通信"))
    }

    func testActivitiesAnalyzedTodayRemainInTheirOriginalDayDigests() async throws {
        let client = SequencedAnalysisClient(summaries: ["跨日批次总结"])
        appState = makeAnalysisAppState(client: client)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        insertActivity(title: "昨日笔记", timestamp: yesterday.addingTimeInterval(3_600))
        insertActivity(title: "今日笔记", timestamp: today.addingTimeInterval(3_600))
        try container.mainContext.save()
        appState.reload()

        await appState.runAnalysis()

        XCTAssertEqual(appState.digests.count, 2)
        let yesterdayDigest = appState.digests.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        let todayDigest = appState.digests.first { calendar.isDate($0.date, inSameDayAs: today) }
        XCTAssertTrue(yesterdayDigest?.summary.contains("昨日笔记") == true)
        XCTAssertTrue(todayDigest?.summary.contains("今日笔记") == true)
        XCTAssertFalse(yesterdayDigest?.summary.contains("今日笔记") == true)
        XCTAssertFalse(todayDigest?.summary.contains("昨日笔记") == true)
        let analysisCallCount = await client.analysisCallCount()
        XCTAssertEqual(analysisCallCount, 1)
    }

    func testTwentyThreeActivitiesUseThreeGlobalBatchesEvenAcrossManyDays() async throws {
        defaults.set(10, forKey: AnalysisPreferences.batchSizeKey)
        let client = SequencedAnalysisClient(summaries: ["第一批", "第二批", "第三批"])
        appState = makeAnalysisAppState(client: client)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        for index in 0..<23 {
            let dayOffset = -(index % 10)
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            insertActivity(
                title: "学习活动 \(index + 1)",
                timestamp: day.addingTimeInterval(TimeInterval(index + 1))
            )
        }
        try container.mainContext.save()
        appState.reload()

        await appState.runAnalysis()

        let analysisCallCount = await client.analysisCallCount()
        XCTAssertEqual(analysisCallCount, 3)
        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<AnalysisRun>()).filter { $0.status == "completed" }.count,
            3
        )
        XCTAssertEqual(appState.pendingActivityCount, 0)
    }

    func testReanalysisReplacesOldBatchSummaryInsteadOfLeavingDuplicates() async throws {
        let client = SequencedAnalysisClient(summaries: ["旧总结", "新总结"])
        appState = makeAnalysisAppState(client: client)
        let activity = insertActivity(title: "旧活动", timestamp: .now.addingTimeInterval(-86_400))
        try container.mainContext.save()
        appState.reload()

        await appState.runAnalysis()
        await appState.reanalyze(activityIDs: [activity.id])

        let summaries = try container.mainContext.fetch(FetchDescriptor<AnalysisBatchSummary>())
        let links = try container.mainContext.fetch(FetchDescriptor<AnalysisBatchActivityLink>())
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.activityID, activity.id)
        XCTAssertEqual(summaries.first?.summary, "新总结")
        XCTAssertTrue(appState.digests.first?.summary.contains("新总结") == true)
        XCTAssertFalse(appState.digests.first?.summary.contains("旧总结") == true)
    }

    private func makeAnalysisAppState(client: SequencedAnalysisClient) -> AppState {
        let state = AppState(
            modelContainer: container,
            aiClient: client,
            automationDefaults: defaults
        )
        let profile = AIEndpointProfile(
            name: "测试接口",
            baseURLString: "https://example.com/v1",
            selectedModelID: "test-model"
        )
        container.mainContext.insert(profile)
        try? container.mainContext.save()
        state.reload()
        state.activeEndpointID = profile.id
        return state
    }

    @discardableResult
    private func insertActivity(title: String, timestamp: Date) -> ActivityEvent {
        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .manual,
            timestamp: timestamp,
            fingerprint: "\(title)-\(UUID().uuidString)",
            title: title,
            sourceLocator: "manual:\(title)",
            summary: title,
            excerpt: title
        )
        container.mainContext.insert(activity)
        return activity
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
            fingerprint: fingerprint,
            origin: .directAssessment,
            verificationLevel: .directChoice,
            assistanceMode: independence >= 0.8 ? .declaredUnassisted : .aiAssisted
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
        try? await Task.sleep(for: .milliseconds(5))
        concurrentScans -= 1
    }
}

@MainActor
private final class AnalysisProbe {
    private(set) var runCount = 0

    func run() -> Bool {
        runCount += 1
        return true
    }
}

private actor SequencedAnalysisClient: AIProviderClient {
    private var summaries: [String]
    private var callCount = 0

    init(summaries: [String]) {
        self.summaries = summaries
    }

    func listModels(endpoint: AIEndpointDescriptor, apiKey: String) async throws -> [RemoteModel] { [] }

    func test(endpoint: AIEndpointDescriptor, modelID: String, apiKey: String) async throws {}

    func analyze(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        activities: [CollectedActivity],
        candidateNodes: [KnowledgeCandidate],
        options: AnalysisOptions
    ) async throws -> AnalysisEnvelope {
        callCount += 1
        let summary = summaries.isEmpty ? "测试总结" : summaries.removeFirst()
        return AnalysisEnvelope(
            sessionSummary: summary,
            evidence: [],
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: nil
        )
    }

    func analysisCallCount() -> Int {
        callCount
    }
}
