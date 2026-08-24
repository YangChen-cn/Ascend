import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class ReviewFlashcardAndMemoryTests: XCTestCase {
    private var container: ModelContainer!
    private var client: AssessmentStubClient!
    private var appState: AppState!
    private var node: KnowledgeNode!
    private let baseDate = Date(timeIntervalSince1970: 2_000_000_000)

    override func setUp() async throws {
        container = PersistenceController.makeContainer(inMemory: true)
        client = AssessmentStubClient(validItemCount: 4)
        appState = AppState(modelContainer: container, aiClient: client)
        node = KnowledgeNode(name: "Swift Actor 并发安全", domain: "Swift", isProvisional: false)
        container.mainContext.insert(node)
        container.mainContext.insert(MasteryState(knowledgeNodeID: node.id))
        try container.mainContext.save()
        appState.reload()
    }

    override func tearDown() async throws {
        appState = nil
        client = nil
        container = nil
        node = nil
    }

    // 1. 到期 ReviewPlan 打开温故页面与提取要点时 AI generation count == 0
    func testOpeningReviewAndExtractingKeyPointsMakesZeroAICalls() async throws {
        let plan = ReviewPlan(
            knowledgeNodeID: node.id,
            createdAt: baseDate.addingTimeInterval(-86_400),
            scheduledAt: baseDate.addingTimeInterval(-100),
            reason: "到期温故",
            status: "due"
        )
        container.mainContext.insert(plan)

        // 添加一条学习实据
        let ev = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: node.id,
            kind: .independentSolve,
            timestamp: baseDate.addingTimeInterval(-86_400),
            summary: "使用 Actor 隔离全局可变状态",
            rationale: "真实代码实践",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.9,
            isVerified: true,
            fingerprint: "test-fp-1",
            origin: .artifact
        )
        container.mainContext.insert(ev)
        try container.mainContext.save()
        appState.reload()

        let points = appState.reviewKeyPoints(for: node.id)
        let sources = appState.reviewSources(for: node.id)

        XCTAssertFalse(points.isEmpty)
        XCTAssertTrue(points.contains(where: { $0.contains("使用 Actor 隔离") }))
        let count = await client.generationCount()
        XCTAssertEqual(count, 0, "温故要点提取完全在本地运行，AI 调用必须为 0")
    }

    // 2. 完成 Again / Hard / Good / Easy 自评时 AI generation count 仍为 0
    func testSelfGradingReviewsMakeZeroAICalls() async throws {
        let plan = ReviewPlan(
            knowledgeNodeID: node.id,
            scheduledAt: baseDate.addingTimeInterval(-10),
            reason: "到期温故",
            status: "due"
        )
        container.mainContext.insert(plan)
        try container.mainContext.save()
        appState.reload()

        try appState.completeCardReview(for: plan, grade: .good, at: baseDate)

        let count = await client.generationCount()
        XCTAssertEqual(count, 0, "温故自评结算必须 0 次 AI API 调用")
    }

    // 3. 温故不会创建 AssessmentSession、AssessmentResponse 或 directChoice MasteryObservation
    func testReviewDoesNotCreateAssessmentSessionOrMasteryObservation() throws {
        let plan = ReviewPlan(
            knowledgeNodeID: node.id,
            scheduledAt: baseDate.addingTimeInterval(-10),
            reason: "到期温故",
            status: "due"
        )
        container.mainContext.insert(plan)
        try container.mainContext.save()
        appState.reload()

        try appState.completeCardReview(for: plan, grade: .good, at: baseDate)

        XCTAssertTrue(appState.assessmentSessions.isEmpty, "温故不得创建 AssessmentSession")
        XCTAssertTrue(appState.assessmentResponses.isEmpty, "温故不得创建 AssessmentResponse")
        XCTAssertTrue(appState.masteryObservations.isEmpty, "温故不得创建 directChoice MasteryObservation")
    }

    // 4. 仅查看要点不自评，不会完成 ReviewPlan 且不更新 FSRS
    func testViewingKeyPointsDoesNotCompleteReviewPlanOrUpdateFSRS() throws {
        let plan = ReviewPlan(
            knowledgeNodeID: node.id,
            scheduledAt: baseDate.addingTimeInterval(-10),
            reason: "到期温故",
            status: "due"
        )
        container.mainContext.insert(plan)
        try container.mainContext.save()
        appState.reload()

        _ = appState.reviewKeyPoints(for: node.id)
        _ = appState.reviewSources(for: node.id)

        XCTAssertEqual(plan.status, "due", "单纯浏览/展开卡片不得完成复习计划")
        XCTAssertTrue(appState.memoryReviewEvents.isEmpty, "单纯浏览不得写入 MemoryReviewEvent")
        XCTAssertNil(appState.memory(for: node.id), "单纯浏览不得创建 MemoryState")
    }

    // 5. Good 正确更新 MemoryReviewEvent、FSRS 记忆与下一次排期时间
    func testGoodReviewUpdatesFSRSAndSchedulesNextPlan() throws {
        let plan = ReviewPlan(
            knowledgeNodeID: node.id,
            scheduledAt: baseDate.addingTimeInterval(-10),
            reason: "到期温故",
            status: "due"
        )
        container.mainContext.insert(plan)
        try container.mainContext.save()
        appState.reload()

        try appState.completeCardReview(for: plan, grade: .good, at: baseDate)

        XCTAssertEqual(plan.status, "completed")
        XCTAssertEqual(appState.memoryReviewEvents.count, 1)
        XCTAssertEqual(appState.memoryReviewEvents[0].grade, .good)
        XCTAssertEqual(appState.memoryReviewEvents[0].sourceRawValue, "cardReview")

        let memory = try XCTUnwrap(appState.memory(for: node.id))
        XCTAssertEqual(memory.reps, 1)
        XCTAssertGreaterThan(memory.nextReviewAt, baseDate)

        // 验证自动排期了下一个 ReviewPlan
        let nextPlans = appState.reviewPlans(for: node.id).filter { $0.status == "scheduled" || $0.status == "due" }
        XCTAssertEqual(nextPlans.count, 1)
        XCTAssertEqual(nextPlans[0].scheduledAt, memory.nextReviewAt)
    }

    // 6. Again 增加 lapse 并缩短下一次复习时间
    func testAgainIncrementsLapseAndShortensInterval() throws {
        // 先做一次 Good
        let plan1 = ReviewPlan(knowledgeNodeID: node.id, scheduledAt: baseDate, reason: "初次", status: "due")
        container.mainContext.insert(plan1)
        try container.mainContext.save()
        appState.reload()
        try appState.completeCardReview(for: plan1, grade: .good, at: baseDate)
        let memoryAfterGood = try XCTUnwrap(appState.memory(for: node.id))

        // 下一次到期时选 Again
        let nextPlan = try XCTUnwrap(appState.reviewPlans(for: node.id).first(where: { $0.status == "scheduled" || $0.status == "due" }))
        let againDate = memoryAfterGood.nextReviewAt
        try appState.completeCardReview(for: nextPlan, grade: .again, at: againDate)

        let memoryAfterAgain = try XCTUnwrap(appState.memory(for: node.id))
        XCTAssertEqual(memoryAfterAgain.lapses, 1)
        XCTAssertEqual(memoryAfterAgain.reps, 2)
        XCTAssertGreaterThanOrEqual(memoryAfterAgain.nextReviewAt, againDate)
    }

    // 7. Easy 相比 Good 产生更长的复习间隔与更高稳定性
    func testEasyProducesHigherStabilityThanGood() throws {
        let nodeEasy = KnowledgeNode(name: "Easy Node", domain: "Swift", isProvisional: false)
        container.mainContext.insert(nodeEasy)
        container.mainContext.insert(MasteryState(knowledgeNodeID: nodeEasy.id))

        let planGood = ReviewPlan(knowledgeNodeID: node.id, scheduledAt: baseDate, reason: "Good", status: "due")
        let planEasy = ReviewPlan(knowledgeNodeID: nodeEasy.id, scheduledAt: baseDate, reason: "Easy", status: "due")
        container.mainContext.insert(planGood)
        container.mainContext.insert(planEasy)
        try container.mainContext.save()
        appState.reload()

        try appState.completeCardReview(for: planGood, grade: .good, at: baseDate)
        try appState.completeCardReview(for: planEasy, grade: .easy, at: baseDate)

        let memoryGood = try XCTUnwrap(appState.memory(for: node.id))
        let memoryEasy = try XCTUnwrap(appState.memory(for: nodeEasy.id))

        XCTAssertGreaterThan(memoryEasy.stability, memoryGood.stability, "Easy 的稳定性应高于 Good")
        XCTAssertGreaterThanOrEqual(memoryEasy.nextReviewAt, memoryGood.nextReviewAt, "Easy 排期时间应晚于或等于 Good")
    }

    // 8. 一个 ReviewPlan 多次调用结算具有幂等性
    func testReviewPlanSettlementIsIdempotent() throws {
        let plan = ReviewPlan(
            knowledgeNodeID: node.id,
            scheduledAt: baseDate.addingTimeInterval(-10),
            reason: "到期温故",
            status: "due"
        )
        container.mainContext.insert(plan)
        try container.mainContext.save()
        appState.reload()

        try appState.completeCardReview(for: plan, grade: .good, at: baseDate)
        let eventCount = appState.memoryReviewEvents.count
        let activePlanCount = appState.reviewPlans(for: node.id).filter { $0.status == "scheduled" || $0.status == "due" }.count

        // 重复调用
        try appState.completeCardReview(for: plan, grade: .good, at: baseDate)

        XCTAssertEqual(appState.memoryReviewEvents.count, eventCount, "重复调用不得插入重复 event")
        let currentActiveCount = appState.reviewPlans(for: node.id).filter { $0.status == "scheduled" || $0.status == "due" }.count
        XCTAssertEqual(currentActiveCount, activePlanCount, "重复调用不得重复创建排期计划")
    }

    // 9. 连续处理多个到期知识点，各知识点独立排期，不混淆
    func testMultipleDueNodesAreHandledIndependently() throws {
        let node2 = KnowledgeNode(name: "并发锁", domain: "Swift", isProvisional: false)
        container.mainContext.insert(node2)
        container.mainContext.insert(MasteryState(knowledgeNodeID: node2.id))

        let plan1 = ReviewPlan(knowledgeNodeID: node.id, scheduledAt: baseDate, reason: "Due 1", status: "due")
        let plan2 = ReviewPlan(knowledgeNodeID: node2.id, scheduledAt: baseDate, reason: "Due 2", status: "due")
        container.mainContext.insert(plan1)
        container.mainContext.insert(plan2)
        try container.mainContext.save()
        appState.reload()

        try appState.completeCardReview(for: plan1, grade: .good, at: baseDate)
        try appState.completeCardReview(for: plan2, grade: .hard, at: baseDate)

        XCTAssertEqual(plan1.status, "completed")
        XCTAssertEqual(plan2.status, "completed")

        let memory1 = try XCTUnwrap(appState.memory(for: node.id))
        let memory2 = try XCTUnwrap(appState.memory(for: node2.id))

        XCTAssertNotEqual(memory1.knowledgeNodeID, memory2.knowledgeNodeID)
        XCTAssertEqual(memory1.reps, 1)
        XCTAssertEqual(memory2.reps, 1)
        XCTAssertNotEqual(memory1.difficulty, memory2.difficulty)
    }

    // 10. 历史 delayedReview 数据能正常从 SwiftData 加载并兼容
    func testLegacyDelayedReviewSessionLoadsSafely() throws {
        let session = AssessmentSession(
            knowledgeNodeID: node.id,
            kind: .delayedReview,
            generatorModelID: "legacy-model",
            reviewPlanID: UUID()
        )
        container.mainContext.insert(session)
        try container.mainContext.save()
        appState.reload()

        let loaded = try XCTUnwrap(appState.assessmentSessions.first(where: { $0.id == session.id }))
        XCTAssertEqual(loaded.kind, .delayedReview)
        XCTAssertEqual(loaded.generatorModelID, "legacy-model")
    }

    // 11. 温故界面能够直接检索并呼出对应知识点的研习笔记与实据预览
    func testLinkedActivitiesForReviewPreview() throws {
        let activityID = UUID()
        let act = ActivityEvent(
            id: activityID,
            sourceID: UUID(),
            sourceKind: .markdownDirectory,
            timestamp: baseDate.addingTimeInterval(-3600),
            fingerprint: "test-fp",
            contentChangeHash: "test-hash",
            title: "Swift 结构化并发与 Actor 隔离笔记",
            sourceLocator: "/notes/swift-actor.md",
            summary: "详解 Actor 隔离规则与数据竞争防御",
            excerpt: "# Swift Actor\n\nActor 保证内部状态在同一时间仅被一个任务访问。"
        )
        container.mainContext.insert(act)

        let ev = EvidenceRecord(
            activityID: activityID,
            knowledgeNodeID: node.id,
            kind: .independentSolve,
            timestamp: baseDate.addingTimeInterval(-3600),
            summary: "详解 Actor 隔离规则",
            rationale: "研习笔记",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.95,
            isVerified: true,
            fingerprint: "test-fp-2",
            origin: .artifact
        )
        container.mainContext.insert(ev)
        try container.mainContext.save()
        appState.reload()

        let linked = appState.linkedActivities(for: node.id)
        XCTAssertEqual(linked.count, 1)
        XCTAssertEqual(linked[0].id, activityID)
        XCTAssertEqual(linked[0].title, "Swift 结构化并发与 Actor 隔离笔记")
        XCTAssertEqual(linked[0].sourceLocator, "/notes/swift-actor.md")
    }
}
