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

    func testReviewKeyPointsDoNotUseAssessmentOrChallengeReceiptAsKnowledgeSummary() throws {
        let assessment = EvidenceRecord(
            activityID: UUID(), knowledgeNodeID: node.id, kind: .exercise, timestamp: baseDate,
            summary: "完成主动验证（覆盖 3 题）", rationale: "选择题判分记录",
            difficulty: 1, independence: 1, aiConfidence: 1, isVerified: true,
            fingerprint: "assessment-summary", origin: .directAssessment, verificationLevel: .directChoice
        )
        let challengeReceipt = EvidenceRecord(
            activityID: UUID(), knowledgeNodeID: node.id, kind: .project, timestamp: baseDate,
            summary: "挑战实作提交 · 后台守护进程", rationale: "AI 核验通过",
            difficulty: 1, independence: 1, aiConfidence: 1, isVerified: true,
            fingerprint: "challenge-summary", origin: .productionPerformance, verificationLevel: .productionRubric
        )
        container.mainContext.insert(assessment)
        container.mainContext.insert(challengeReceipt)
        try container.mainContext.save()
        appState.reload()

        let points = appState.reviewKeyPoints(for: node.id)

        XCTAssertFalse(points.contains(where: { $0.contains("完成主动验证") || $0.contains("挑战实作提交") }))
        XCTAssertTrue(points.contains(where: { $0.contains(node.name) }))
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

    // 12. 未验证 evidence 不出现在温故卡
    func testUnverifiedEvidenceDoesNotAppearOnReviewFlashcardDeck() throws {
        let unverifiedEV = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: node.id,
            kind: .explanation,
            timestamp: baseDate.addingTimeInterval(-100),
            summary: "未验证的草稿解析",
            rationale: "待审核",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.5,
            isVerified: false,
            fingerprint: "unverified-fp",
            origin: .artifact
        )
        container.mainContext.insert(unverifiedEV)
        try container.mainContext.save()
        appState.reload()

        let points = appState.reviewKeyPoints(for: node.id)
        XCTAssertFalse(points.contains(where: { $0.contains("未验证的草稿解析") }))
        let activities = appState.linkedActivities(for: node.id)
        XCTAssertTrue(activities.isEmpty)
        let sources = appState.reviewSources(for: node.id)
        XCTAssertTrue(sources.isEmpty)

        // 验证通过后方可出现
        unverifiedEV.isVerified = true
        try container.mainContext.save()
        appState.reload()

        let updatedPoints = appState.reviewKeyPoints(for: node.id)
        XCTAssertTrue(updatedPoints.contains(where: { $0.contains("未验证的草稿解析") }))
    }

    // 13. 未确认 provisional artifact 可以产生弱成长，且审核后不重复奖励
    func testUnverifiedProvisionalArtifactAwardsWeakGrowthAndDoesNotDoubleAwardOnApproval() throws {
        let unverifiedEV = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: node.id,
            kind: .project,
            timestamp: baseDate,
            summary: "未确认项目代码",
            rationale: "未通过审核",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.7,
            isVerified: false,
            fingerprint: "unverified-artifact-fp",
            origin: .artifact
        )
        container.mainContext.insert(unverifiedEV)
        try container.mainContext.save()
        appState.reload()

        let xp = appState.applyArtifactEvidence(unverifiedEV)
        XCTAssertGreaterThan(xp, 0, "真实未确认 artifact 必须获得弱成长 XP")

        let state = try XCTUnwrap(appState.mastery(for: node.id))
        XCTAssertEqual(state.lifetimeXP, xp)
        XCTAssertGreaterThan(state.vector.composite, 0)
        XCTAssertLessThanOrEqual(state.highestStage.level, MasteryStage.proficient.level)

        // 审核批准后不得产生二次/双倍奖励
        unverifiedEV.isVerified = true
        let secondXP = appState.applyArtifactEvidence(unverifiedEV)
        XCTAssertEqual(secondXP, 0, "审核后不能重复奖励双倍 XP")
        XCTAssertEqual(state.lifetimeXP, xp, "XP 总额保持不变，幂等安全")
    }

    // 14. 答错 assessment 不显示“已印证”
    func testFailedAssessmentDoesNotShowCertified() throws {
        // 设置为通晓接近融会状态（突破验证候选）
        if let state = appState.mastery(for: node.id) {
            state.vector = MasteryVector(exposure: 50, understanding: 50, practice: 50, retention: 50, autonomy: 50)
            state.highestStageRawValue = MasteryStage.proficient.rawValue
            try container.mainContext.save()
            appState.reload()
        }

        let session = AssessmentSession(knowledgeNodeID: node.id, kind: .baseline, generatorModelID: "test-model")
        let packageItem = AssessmentPackage.Item(
            id: UUID(),
            knowledgeNodeID: node.id,
            tier: .foundational,
            stem: "测试题",
            answerOptions: ["A", "B", "C", "D"],
            correctAnswerIndex: 0,
            reasoningPrompt: "理由",
            reasoningOptions: ["R1", "R2", "R3", "R4"],
            correctReasoningIndex: 0,
            explanation: "解析",
            misconceptionTags: [],
            sourceActivityIDs: []
        )
        let item = AssessmentItem(sessionID: session.id, item: packageItem)
        session.presentedItemIDs = [item.id]
        container.mainContext.insert(session)
        container.mainContext.insert(item)
        try container.mainContext.save()
        appState.reload()

        _ = try appState.recordAssessmentResponse(session: session, item: item, selectedAnswerIndex: 1, selectedReasoningIndex: 1, usedAssistance: false)

        let snapshot = try XCTUnwrap(appState.readiness(for: node.id))
        XCTAssertFalse(snapshot.isCertified, "答错题目绝不能显示已印证")
        XCTAssertEqual(snapshot.verificationBadgeTitle, "尚未通过")
        XCTAssertTrue(snapshot.stageDisplayTitle.contains("尚未通过"))
    }

    // 15. embedded package 不让低阶段节点进入 pending verification
    func testEmbeddedPackageDoesNotMakeLowStageNodeEnterPendingVerification() throws {
        let session = AssessmentSession(knowledgeNodeID: node.id, kind: .baseline, generatorModelID: "analysis-model")
        let packageItem = AssessmentPackage.Item(
            id: UUID(),
            knowledgeNodeID: node.id,
            tier: .foundational,
            stem: "缓存题",
            answerOptions: ["A", "B", "C", "D"],
            correctAnswerIndex: 0,
            reasoningPrompt: "理由",
            reasoningOptions: ["R1", "R2", "R3", "R4"],
            correctReasoningIndex: 0,
            explanation: "解析",
            misconceptionTags: [],
            sourceActivityIDs: []
        )
        let item = AssessmentItem(sessionID: session.id, item: packageItem)
        container.mainContext.insert(session)
        container.mainContext.insert(item)
        try container.mainContext.save()
        appState.reload()

        // 知识点当前为初窥（composite = 0），未达到 >= 45 突破候选门槛
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 0, "低阶段缓存题包不得增加待验证计数")
        XCTAssertEqual(appState.pendingVerificationKnowledgeCount, 0, "低阶段缓存题包不得制造验证负债")
    }

    // 16. 温故无数据时不显示 100%，返回 nil
    func testReviewNoDataReturnsNilRetention() throws {
        let retention = appState.currentRetention(for: node.id)
        XCTAssertNil(retention, "无 FSRS / MemoryState 数据时 currentRetention 必须为 nil")
    }

    // 17. 融会不能仅凭 estimate >= 0.60 获得认证
    func testIntegratedStageCannotBeCertifiedMerelyBySingleEstimateAbove60() throws {
        for dimension in MasteryDimension.allCases {
            let estimate = MasteryEstimate(
                knowledgeNodeID: node.id,
                dimension: dimension,
                probability: 0.70,
                observationCount: 1,
                correctCount: 1,
                lastObservedAt: baseDate,
                modelVersion: MasteryEstimator.modelVersion
            )
            container.mainContext.insert(estimate)
        }
        try container.mainContext.save()
        appState.reload()

        let snapshot = try XCTUnwrap(appState.readiness(for: node.id))
        XCTAssertEqual(snapshot.certifiedStage, .proficient, "缺少独立主动验证时，融会必须受阻并停留在通晓")
        XCTAssertFalse(snapshot.isCertified)
        XCTAssertEqual(snapshot.stageBlockReason, "融会需要至少一次独立主动验证")
    }

    // 18. 导入 40 个新知识点无需人工审核即刻获得初始自然成长，且绝不超过通晓
    func testImportFortyProvisionalNodesGainImmediateNaturalGrowth() throws {
        var events: [ActivityEvent] = []
        var evidenceItems: [AnalyzedEvidence] = []
        var suggestions: [NodeSuggestion] = []

        for i in 1...40 {
            let act = ActivityEvent(
                sourceID: UUID(),
                sourceKind: .markdownDirectory,
                timestamp: baseDate.addingTimeInterval(Double(i * 10)),
                fingerprint: "fp-bulk-\(i)",
                contentChangeHash: "hash-bulk-\(i)",
                title: "学习笔记 \(i)",
                sourceLocator: "/notes/topic-\(i).md",
                summary: "系统分析研习要点 \(i)",
                excerpt: "正文内容 \(i)"
            )
            container.mainContext.insert(act)
            events.append(act)

            let topicName = "知窍知识点 \(i)"
            suggestions.append(NodeSuggestion(
                proposedName: topicName,
                domain: "系统架构",
                confidence: 0.88,
                rationale: "核心概念"
            ))
            evidenceItems.append(AnalyzedEvidence(
                activityID: act.id,
                knowledgeName: topicName,
                matchedNodeID: nil,
                matchConfidence: 0.85,
                kind: i % 2 == 0 ? .project : .explanation,
                difficulty: 1.0,
                independence: 1.0,
                confidence: 0.85,
                summary: "深入理解并实践 \(topicName)",
                rationale: "架构实据"
            ))
        }

        try container.mainContext.save()
        appState.reload()

        let envelope = AnalysisEnvelope(
            sessionSummary: "导入 40 个知识点批量分析总结",
            evidence: evidenceItems,
            nodeSuggestions: suggestions,
            edgeSuggestions: [],
            challengeSuggestion: nil
        )
        let run = AnalysisRun(endpointProfileID: nil, modelID: "test-model", activityCount: events.count)

        let awardedXP = try appState.apply(envelope: envelope, to: events, analysisRun: run)
        XCTAssertGreaterThan(awardedXP, 0, "40 个新知识点分析完成必须产出自然成长总 XP")

        // 验证 40 个知识点与 MasteryState 均已创建，且全部有 > 0 的自然成长与 XP
        let createdNodes = appState.knowledgeNodes.filter { $0.name.hasPrefix("知窍知识点") }
        XCTAssertEqual(createdNodes.count, 40)

        for node in createdNodes {
            XCTAssertTrue(node.isProvisional, "新导入节点保持 provisional 状态")
            let mastery = try XCTUnwrap(appState.mastery(for: node.id))
            XCTAssertGreaterThan(mastery.vector.composite, 0, "“\(node.name)”必须有大于 0 的掌握度成长")
            XCTAssertGreaterThan(mastery.lifetimeXP, 0, "“\(node.name)”必须获得真实研习 XP")

            let snapshot = try XCTUnwrap(appState.readiness(for: node.id))
            XCTAssertLessThanOrEqual(snapshot.certifiedStage.level, MasteryStage.proficient.level, "弱实据成长最高不得超过通晓")
        }

        let totalXP = appState.masteryStates.reduce(0) { $0 + $1.lifetimeXP }
        XCTAssertGreaterThan(totalXP, 0, "全量 40 个知识点总 XP 必须大于 0，不再全部为 0")
    }
}
