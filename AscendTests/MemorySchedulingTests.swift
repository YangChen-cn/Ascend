import SwiftData
import XCTest
@testable import Ascend

final class MemorySchedulingTests: XCTestCase {
    private let scheduler = FSRSMemoryScheduler()
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testGoodCreatesMemoryAndIncreasesStability() throws {
        let first = try scheduler.review(state: nil, grade: .good, at: now, desiredRetention: 0.9)
        let secondDate = first.state.nextReviewAt
        let second = try scheduler.review(state: first.state, grade: .good, at: secondDate, desiredRetention: 0.9)

        XCTAssertEqual(first.state.reps, 1)
        XCTAssertGreaterThan(first.state.stability, 0)
        XCTAssertGreaterThan(first.state.nextReviewAt, now)
        XCTAssertGreaterThan(second.state.stability, first.state.stability)
        XCTAssertEqual(second.state.reps, 2)
    }

    func testAgainIncrementsLapseAndSchedulesNextReview() throws {
        let first = try scheduler.review(state: nil, grade: .good, at: now, desiredRetention: 0.9)
        let failedAt = first.state.nextReviewAt
        let failed = try scheduler.review(state: first.state, grade: .again, at: failedAt, desiredRetention: 0.9)

        XCTAssertEqual(failed.state.lapses, first.state.lapses + 1)
        XCTAssertGreaterThanOrEqual(failed.state.nextReviewAt, failedAt)
    }

    func testRetrievabilityFallsAsTimePasses() throws {
        let reviewed = try scheduler.review(state: nil, grade: .good, at: now, desiredRetention: 0.9)
        let immediately = try scheduler.retrievability(state: reviewed.state, at: now, desiredRetention: 0.9)
        let later = try scheduler.retrievability(
            state: reviewed.state,
            at: now.addingTimeInterval(30 * 86_400),
            desiredRetention: 0.9
        )

        XCTAssertGreaterThan(immediately, later)
        XCTAssertGreaterThanOrEqual(later, 0)
    }

    func testHigherDesiredRetentionProducesShorterInterval() throws {
        let lower = try scheduler.review(state: nil, grade: .good, at: now, desiredRetention: 0.8)
        let higher = try scheduler.review(state: nil, grade: .good, at: now, desiredRetention: 0.95)

        XCTAssertLessThanOrEqual(higher.state.nextReviewAt, lower.state.nextReviewAt)
    }

    func testExposureAndUnverifiedEvidenceNeverBecomeReviews() {
        XCTAssertNil(
            MemoryReviewEligibility.inferredGrade(
                for: MemoryReviewEvidenceSnapshot(kind: .exposure, confidence: 1, independence: 1, isVerified: true)
            )
        )
        XCTAssertNil(
            MemoryReviewEligibility.inferredGrade(
                for: MemoryReviewEvidenceSnapshot(kind: .review, confidence: 1, independence: 1, isVerified: false)
            )
        )
        XCTAssertNil(
            MemoryReviewEligibility.inferredGrade(
                for: MemoryReviewEvidenceSnapshot(kind: .explanation, confidence: 1, independence: 1, isVerified: true)
            )
        )
        XCTAssertNil(
            MemoryReviewEligibility.inferredGrade(
                for: MemoryReviewEvidenceSnapshot(kind: .exercise, confidence: 1, independence: 1, isVerified: true)
            )
        )
        XCTAssertEqual(
            MemoryReviewEligibility.inferredGrade(
                for: MemoryReviewEvidenceSnapshot(kind: .independentSolve, confidence: 1, independence: 1, isVerified: true)
            ),
            .good
        )
    }

    func testReplayOfSameEventsIsDeterministic() throws {
        let events: [(MemoryReviewGrade, Date)] = [
            (.good, now),
            (.hard, now.addingTimeInterval(3 * 86_400)),
            (.again, now.addingTimeInterval(7 * 86_400)),
            (.good, now.addingTimeInterval(8 * 86_400))
        ]

        func replay() throws -> MemorySchedulingResult? {
            var state: MemorySchedulingState?
            var result: MemorySchedulingResult?
            for event in events {
                result = try scheduler.review(state: state, grade: event.0, at: event.1, desiredRetention: 0.9)
                state = result?.state
            }
            return result
        }

        XCTAssertEqual(try replay(), try replay())
    }
}

@MainActor
final class MemoryPersistenceIntegrationTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!

    override func setUp() async throws {
        container = PersistenceController.makeContainer(inMemory: true)
        appState = AppState(modelContainer: container)
    }

    override func tearDown() async throws {
        appState = nil
        container = nil
    }

    func testCanonicalDuplicateEvidenceUpdatesMemoryOnlyOnce() throws {
        let node = KnowledgeNode(name: "waitpid", domain: "Linux", isProvisional: false)
        let mastery = MasteryState(knowledgeNodeID: node.id)
        let first = activity(fingerprint: "local", contentHash: "same-change")
        let second = activity(fingerprint: "remote", contentHash: "same-change")
        container.mainContext.insert(node)
        container.mainContext.insert(mastery)
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()
        appState.reload()

        let run = AnalysisRun(endpointProfileID: nil, modelID: "mock", activityCount: 2)
        container.mainContext.insert(run)
        let envelope = AnalysisEnvelope(
            sessionSummary: "练习 waitpid",
            evidence: [first, second].map {
                AnalyzedEvidence(
                    activityID: $0.id,
                    knowledgeName: node.name,
                    matchedNodeID: node.id,
                    matchConfidence: 0.96,
                    kind: .independentSolve,
                    difficulty: 1,
                    independence: 1,
                    confidence: 0.96,
                    summary: "主动回忆并练习 waitpid",
                    rationale: "真实练习"
                )
            },
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: nil
        )

        _ = try appState.apply(envelope: envelope, to: [first, second], analysisRun: run)

        XCTAssertEqual(appState.memoryReviewEvents.count, 1)
        XCTAssertEqual(appState.memory(for: node.id)?.reps, 1)
    }

    func testExposureAndUnverifiedRetrievalDoNotCreateMemoryState() throws {
        let node = KnowledgeNode(name: "进程", domain: "Linux", isProvisional: false)
        let mastery = MasteryState(knowledgeNodeID: node.id)
        let exposure = activity(fingerprint: "read", contentHash: "read-change")
        let unverifiedReview = activity(fingerprint: "review", contentHash: "review-change")
        container.mainContext.insert(node)
        container.mainContext.insert(mastery)
        container.mainContext.insert(exposure)
        container.mainContext.insert(unverifiedReview)
        try container.mainContext.save()
        appState.reload()

        let run = AnalysisRun(endpointProfileID: nil, modelID: "mock", activityCount: 2)
        container.mainContext.insert(run)
        let envelope = AnalysisEnvelope(
            sessionSummary: "阅读并尝试回忆进程概念",
            evidence: [
                AnalyzedEvidence(
                    activityID: exposure.id,
                    knowledgeName: node.name,
                    matchedNodeID: node.id,
                    matchConfidence: 0.96,
                    kind: .exposure,
                    difficulty: 1,
                    independence: 1,
                    confidence: 0.96,
                    summary: "阅读进程概念",
                    rationale: "仅接触内容"
                ),
                AnalyzedEvidence(
                    activityID: unverifiedReview.id,
                    knowledgeName: node.name,
                    matchedNodeID: node.id,
                    matchConfidence: 0.70,
                    kind: .review,
                    difficulty: 1,
                    independence: 1,
                    confidence: 0.96,
                    summary: "尝试回忆进程概念",
                    rationale: "匹配仍需确认"
                )
            ],
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: nil
        )

        _ = try appState.apply(envelope: envelope, to: [exposure, unverifiedReview], analysisRun: run)

        XCTAssertTrue(appState.memoryReviewEvents.isEmpty)
        XCTAssertNil(appState.memory(for: node.id))
        XCTAssertEqual(appState.evidenceRecords.filter(\.isVerified).map(\.kind), [.exposure])
    }

    func testExplicitReviewCompletesCurrentPlanAndCreatesNextPlan() throws {
        let now = Date(timeIntervalSince1970: 2_100_000_000)
        let node = KnowledgeNode(name: "fork", domain: "Linux", isProvisional: false)
        let mastery = MasteryState(knowledgeNodeID: node.id)
        let plan = ReviewPlan(
            knowledgeNodeID: node.id,
            createdAt: now.addingTimeInterval(-86_400),
            scheduledAt: now.addingTimeInterval(-60),
            reason: "到期温故",
            status: "due"
        )
        container.mainContext.insert(node)
        container.mainContext.insert(mastery)
        container.mainContext.insert(plan)
        try container.mainContext.save()
        appState.reload()

        try appState.recordReviewGrade(for: node.id, grade: .good, at: now)

        XCTAssertEqual(plan.status, "completed")
        let active = appState.reviewPlans.filter {
            $0.knowledgeNodeID == node.id && ($0.status == "scheduled" || $0.status == "due")
        }
        XCTAssertEqual(active.count, 1)
        XCTAssertGreaterThanOrEqual(active[0].scheduledAt, now)
    }

    private func activity(fingerprint: String, contentHash: String) -> ActivityEvent {
        ActivityEvent(
            sourceID: UUID(),
            sourceKind: .markdownDirectory,
            timestamp: .now,
            fingerprint: fingerprint,
            contentChangeHash: contentHash,
            title: "waitpid 练习",
            sourceLocator: "/notes/waitpid.md",
            summary: "练习 waitpid",
            excerpt: ""
        )
    }
}
