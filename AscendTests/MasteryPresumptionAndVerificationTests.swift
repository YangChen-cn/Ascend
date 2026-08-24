import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class MasteryPresumptionAndVerificationTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!
    private var node: KnowledgeNode!

    override func setUp() async throws {
        container = PersistenceController.makeContainer(inMemory: true)
        appState = AppState(modelContainer: container)
        node = KnowledgeNode(name: "Swift Concurrency", domain: "Swift", isProvisional: false)
        container.mainContext.insert(node)
        container.mainContext.insert(MasteryState(knowledgeNodeID: node.id))
        try container.mainContext.save()
        appState.reload()
    }

    // 1. Artifact 可以推动初窥 → 入门 → 通晓，但不能单独达到融会
    func testArtifactEvidencePushesEntryToAdvancingToProficientButCappedBelowIntegrated() throws {
        let state = try XCTUnwrap(appState.mastery(for: node.id))
        XCTAssertEqual(state.highestStage, .entry)

        // 添加 1 个 exposure 证据
        let ev1 = makeArtifactEvidence(kind: .exposure, daysAgo: 3)
        appState.applyArtifactEvidence(ev1)
        let snapshot1 = try XCTUnwrap(appState.readiness(for: node.id))
        XCTAssertEqual(snapshot1.certifiedStage, .entry)
        XCTAssertGreaterThan(snapshot1.currentComposite, 0)
        XCTAssertGreaterThan(state.lifetimeXP, 0)

        // 添加多种维度的研习证据推动成长至入门与通晓
        let kinds: [EvidenceKind] = [.exposure, .explanation, .exercise, .project, .independentSolve]
        for (i, kind) in (0..<30).map({ ($0, kinds[$0 % kinds.count]) }) {
            let ev = makeArtifactEvidence(kind: kind, daysAgo: Double(i))
            appState.applyArtifactEvidence(ev)
        }
        let snapshot2 = try XCTUnwrap(appState.readiness(for: node.id))
        // 达到通晓 (40~59.9)
        XCTAssertGreaterThanOrEqual(snapshot2.currentComposite, 40)
        XCTAssertEqual(snapshot2.certifiedStage, .proficient)
        XCTAssertEqual(state.highestStage, .proficient)

        // 再添加大量 artifact 证据，即便 composite 算至 60+，未印证时 certifiedStage 仍被严格截断在通晓
        for (i, kind) in (30..<70).map({ ($0, kinds[$0 % kinds.count]) }) {
            let ev = makeArtifactEvidence(kind: kind, daysAgo: Double(i))
            appState.applyArtifactEvidence(ev)
        }
        let snapshot3 = try XCTUnwrap(appState.readiness(for: node.id))
        XCTAssertEqual(snapshot3.certifiedStage, .proficient, "无直接验证时，纯 artifact 绝不能认证到融会")
        XCTAssertEqual(state.highestStage, .proficient)
        XCTAssertGreaterThanOrEqual(snapshot3.currentComposite, 60)
        XCTAssertNotNil(snapshot3.stageBlockReason)
        XCTAssertTrue(snapshot3.stageBlockReason?.contains("融会需要") == true)
    }

    // 2. 没答题时境界仍可因学习证据增长并获得 XP
    func testMasteryAndXPGrowNaturallyFromEvidenceWithoutTakingAssessment() throws {
        let state = try XCTUnwrap(appState.mastery(for: node.id))
        let initialXP = state.lifetimeXP
        XCTAssertEqual(initialXP, 0)

        let ev1 = makeArtifactEvidence(kind: .explanation, daysAgo: 2)
        let xp1 = appState.applyArtifactEvidence(ev1)
        XCTAssertGreaterThan(xp1, 0)
        XCTAssertEqual(state.lifetimeXP, xp1)

        let ev2 = makeArtifactEvidence(kind: .exercise, daysAgo: 1)
        let xp2 = appState.applyArtifactEvidence(ev2)
        XCTAssertGreaterThan(xp2, 0)
        XCTAssertEqual(state.lifetimeXP, xp1 + xp2)
        XCTAssertGreaterThan(state.vector.composite, 0)
    }

    // 3. 融会必须存在 direct assessment
    func testIntegratedRequiresDirectAssessmentPassing() throws {
        // 先通过 artifact 推高到 50+
        for i in 0..<10 {
            let ev = makeArtifactEvidence(kind: .project, daysAgo: Double(i))
            appState.applyArtifactEvidence(ev)
        }

        // 添加直接测评通过表现（MasteryEstimate 60+）
        for dim in MasteryDimension.allCases {
            let est = MasteryEstimate(
                knowledgeNodeID: node.id,
                dimension: dim,
                probability: 0.65,
                observationCount: 2,
                correctCount: 2,
                lastObservedAt: .now,
                modelVersion: MasteryEstimator.modelVersion
            )
            container.mainContext.insert(est)
        }
        let responseID = UUID()
        let obs = MasteryObservation(
            canonicalKey: "pass-obs",
            sessionID: UUID(),
            itemID: UUID(),
            responseID: responseID,
            knowledgeNodeID: node.id,
            dimension: .understanding,
            isCorrect: true,
            guessProbability: 0.25,
            slipProbability: 0.1,
            priorProbability: 0.5,
            predictedCorrectProbability: 0.65,
            posteriorProbability: 0.65,
            observedAt: .now,
            modelVersion: MasteryEstimator.modelVersion
        )
        container.mainContext.insert(obs)
        try container.mainContext.save()
        appState.reload()

        let snapshot = try XCTUnwrap(appState.readiness(for: node.id))
        XCTAssertEqual(snapshot.certifiedStage, .integrated, "有直接测评且达到 60 分即可认证为融会")
        XCTAssertNil(snapshot.stageBlockReason)
    }

    // 4. 化用 / 通达仍受 production gate 限制
    func testConnectedAndMasteredRequireProductionPerformanceGates() throws {
        // 先设高分 95
        for dim in MasteryDimension.allCases {
            let est = MasteryEstimate(
                knowledgeNodeID: node.id,
                dimension: dim,
                probability: 0.95,
                observationCount: 3,
                correctCount: 3,
                lastObservedAt: .now,
                modelVersion: MasteryEstimator.modelVersion
            )
            container.mainContext.insert(est)
        }
        let responseID = UUID()
        container.mainContext.insert(
            MasteryObservation(
                canonicalKey: "pass-obs",
                sessionID: UUID(),
                itemID: UUID(),
                responseID: responseID,
                knowledgeNodeID: node.id,
                dimension: .understanding,
                isCorrect: true,
                guessProbability: 0.25,
                slipProbability: 0.1,
                priorProbability: 0.5,
                predictedCorrectProbability: 0.95,
                posteriorProbability: 0.95,
                observedAt: .now,
                modelVersion: MasteryEstimator.modelVersion
            )
        )
        try container.mainContext.save()
        appState.reload()

        // 无实作时，最多到融会
        let snapshot1 = try XCTUnwrap(appState.readiness(for: node.id))
        XCTAssertEqual(snapshot1.certifiedStage, .integrated)
        XCTAssertTrue(snapshot1.stageBlockReason?.contains("实作") == true)

        // 1 次实作 -> 化用
        let day1 = Date(timeIntervalSince1970: 2_000_000_000)
        try appState.recordVerifiedPerformance(
            for: node.id,
            contextHash: "context-1",
            summary: "实作 1",
            score: 0.9,
            scoringConfidence: 0.9,
            verificationLevel: .productionDeterministic,
            assistanceMode: .declaredUnassisted,
            occurredAt: day1
        )
        let snapshot2 = try XCTUnwrap(appState.readiness(for: node.id, now: day1))
        XCTAssertEqual(snapshot2.certifiedStage, .connected)

        // 2 次实作但间隔 < 7 天 -> 仍为化用
        try appState.recordVerifiedPerformance(
            for: node.id,
            contextHash: "context-2",
            summary: "实作 2",
            score: 0.95,
            scoringConfidence: 0.9,
            verificationLevel: .productionDeterministic,
            assistanceMode: .declaredUnassisted,
            occurredAt: day1.addingTimeInterval(3 * 86_400)
        )
        let snapshot3 = try XCTUnwrap(appState.readiness(for: node.id, now: day1.addingTimeInterval(3 * 86_400)))
        XCTAssertEqual(snapshot3.certifiedStage, .connected)

        // 2 次实作且间隔 >= 7 天 -> 通达
        try appState.recordVerifiedPerformance(
            for: node.id,
            contextHash: "context-3",
            summary: "实作 3",
            score: 0.95,
            scoringConfidence: 0.9,
            verificationLevel: .productionDeterministic,
            assistanceMode: .declaredUnassisted,
            occurredAt: day1.addingTimeInterval(8 * 86_400)
        )
        let snapshot4 = try XCTUnwrap(appState.readiness(for: node.id, now: day1.addingTimeInterval(8 * 86_400)))
        XCTAssertEqual(snapshot4.certifiedStage, .mastered)
    }

    // 5. Baseline 首题足够明确时 1 题即可结束
    func testBaselineConcludesInOneQuestionWhenFirstAnswerIsDecisive() async throws {
        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 4)
        let firstItem = items[0]

        let progress = try appState.recordAssessmentResponse(
            session: session,
            item: firstItem,
            selectedAnswerIndex: firstItem.correctAnswerIndex,
            selectedReasoningIndex: firstItem.correctReasoningIndex,
            usedAssistance: false
        )

        XCTAssertTrue(progress.isCompleted, "首题完全答对且独立，自适应直接结束")
        XCTAssertEqual(session.statusRawValue, "completed")
        XCTAssertEqual(appState.responses(for: session.id).count, 1)
    }

    // 6. 不确定时最多继续到 2～3 题
    func testAssessmentContinuesToTwoOrThreeQuestionsWhenFirstIsMissed() async throws {
        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 4)
        let firstItem = items[0]

        // 第 1 题答错
        let progress1 = try appState.recordAssessmentResponse(
            session: session,
            item: firstItem,
            selectedAnswerIndex: (firstItem.correctAnswerIndex + 1) % 4,
            selectedReasoningIndex: firstItem.correctReasoningIndex,
            usedAssistance: false
        )
        XCTAssertFalse(progress1.isCompleted, "首题答错应继续测试")
        XCTAssertNotNil(progress1.nextItemID)

        // 第 2 题答对（与第 1 题不一致）
        let secondItem = try XCTUnwrap(appState.currentItem(for: session))
        let progress2 = try appState.recordAssessmentResponse(
            session: session,
            item: secondItem,
            selectedAnswerIndex: secondItem.correctAnswerIndex,
            selectedReasoningIndex: secondItem.correctReasoningIndex,
            usedAssistance: false
        )
        XCTAssertFalse(progress2.isCompleted, "1 错 1 对不一致应出第 3 题")

        // 第 3 题答完（达到 3 题上限）
        let thirdItem = try XCTUnwrap(appState.currentItem(for: session))
        let progress3 = try appState.recordAssessmentResponse(
            session: session,
            item: thirdItem,
            selectedAnswerIndex: thirdItem.correctAnswerIndex,
            selectedReasoningIndex: thirdItem.correctReasoningIndex,
            usedAssistance: false
        )
        XCTAssertTrue(progress3.isCompleted, "最多 3 题必须结束")
        XCTAssertEqual(appState.responses(for: session.id).count, 3)
    }

    // 7. Skip 不产生 mastery observations，不降低 posterior，不奖励 XP
    func testSkipProducesNoObservationsDoesNotLowerEstimateAndAwardsNoXP() async throws {
        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 3)
        let firstItem = items[0]

        let initialObservations = appState.masteryObservations.count
        let initialXP = appState.totalXP

        let progress = try appState.skipAssessmentItem(session: session, item: firstItem)
        let response = try XCTUnwrap(appState.responses(for: session.id).first)

        XCTAssertTrue(response.wasSkipped)
        XCTAssertEqual(appState.masteryObservations.count, initialObservations, "跳过绝不产生 mastery observation")
        XCTAssertEqual(appState.totalXP, initialXP)
        XCTAssertNotNil(progress.nextItemID, "跳过允许继续进行")
    }

    // 8. 未完成 session 不产生永久 highestStage / peak XP
    func testIncompleteSessionDoesNotPermanentlyAdvanceHighestStageOrPeakXP() async throws {
        let state = try XCTUnwrap(appState.mastery(for: node.id))
        XCTAssertEqual(state.lifetimeXP, 0)
        XCTAssertEqual(state.highestStage, .entry)

        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 3)
        let firstItem = items[0]

        // 答错第 1 题（session 处于 active，未 finalize）
        _ = try appState.recordAssessmentResponse(
            session: session,
            item: firstItem,
            selectedAnswerIndex: (firstItem.correctAnswerIndex + 1) % 4,
            selectedReasoningIndex: firstItem.correctReasoningIndex,
            usedAssistance: false
        )

        XCTAssertEqual(session.statusRawValue, "active")
        XCTAssertEqual(state.lifetimeXP, 0, "未完成 session 不得提前结算永久 XP")
    }

    // 9. Confidence 按 unique response 计算，不因双 observation 虚高
    func testConfidenceCalculatedByUniqueResponseCount() throws {
        let state = try XCTUnwrap(appState.mastery(for: node.id))
        let responseID = UUID()

        // 1 题写入 2 个 observation（primary + understanding）
        let obs1 = MasteryObservation(
            canonicalKey: "c1",
            sessionID: UUID(),
            itemID: UUID(),
            responseID: responseID,
            knowledgeNodeID: node.id,
            dimension: .exposure,
            isCorrect: true,
            guessProbability: 0.25,
            slipProbability: 0.1,
            priorProbability: 0.5,
            predictedCorrectProbability: 0.6,
            posteriorProbability: 0.6,
            observedAt: .now,
            modelVersion: 1
        )
        let obs2 = MasteryObservation(
            canonicalKey: "c2",
            sessionID: UUID(),
            itemID: UUID(),
            responseID: responseID,
            knowledgeNodeID: node.id,
            dimension: .understanding,
            isCorrect: true,
            guessProbability: 0.25,
            slipProbability: 0.1,
            priorProbability: 0.5,
            predictedCorrectProbability: 0.6,
            posteriorProbability: 0.6,
            observedAt: .now,
            modelVersion: 1
        )
        container.mainContext.insert(obs1)
        container.mainContext.insert(obs2)
        try container.mainContext.save()
        appState.reload()

        let snapshot = try XCTUnwrap(appState.readiness(for: node.id))
        // 1 个 response 不应达到 100% confidence
        XCTAssertEqual(snapshot.observationCount, 1)
        XCTAssertEqual(snapshot.measurementStatus, .supported)
    }

    // 10. 只答第一题后中途退出（未完成）不会创建首次 FSRS review
    func testIncompleteSessionDoesNotCreateFSRSReviewPlan() async throws {
        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 3)
        let firstItem = items[0]

        // 答错第 1 题（session 未完成）
        _ = try appState.recordAssessmentResponse(
            session: session,
            item: firstItem,
            selectedAnswerIndex: (firstItem.correctAnswerIndex + 1) % 4,
            selectedReasoningIndex: firstItem.correctReasoningIndex,
            usedAssistance: false
        )

        XCTAssertEqual(session.statusRawValue, "active")
        XCTAssertTrue(appState.reviewPlans.filter({ $0.knowledgeNodeID == node.id }).isEmpty, "未完成 session 绝不创建 ReviewPlan")
    }

    // 11. 正式完成首次验证后才创建延迟复习
    func testCompletedBaselineCreatesInitialFSRSReviewPlan() async throws {
        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 3)
        let firstItem = items[0]

        _ = try appState.recordAssessmentResponse(
            session: session,
            item: firstItem,
            selectedAnswerIndex: firstItem.correctAnswerIndex,
            selectedReasoningIndex: firstItem.correctReasoningIndex,
            usedAssistance: false
        )

        XCTAssertEqual(session.statusRawValue, "completed")
        let plan = try XCTUnwrap(appState.reviewPlans.first(where: { $0.knowledgeNodeID == node.id }))
        XCTAssertEqual(plan.status, "scheduled")
        XCTAssertGreaterThan(plan.scheduledAt, Date.now.addingTimeInterval(86_000))
    }

    // 12. Hard / Easy 非强制，默认答对可以自动按 Good 处理
    func testDelayedReviewDefaultsToGoodAutomaticallyWithoutBlocking() async throws {
        // 先建立复习计划与 FSRS 记忆
        try appState.scheduleReview(for: node.id, scheduledAt: .now.addingTimeInterval(-10), reason: "到期")
        let plan = try XCTUnwrap(appState.reviewPlans.first(where: { $0.knowledgeNodeID == node.id }))

        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 2, kind: .delayedReview, planID: plan.id)
        let firstItem = items[0]

        let progress = try appState.recordAssessmentResponse(
            session: session,
            item: firstItem,
            selectedAnswerIndex: firstItem.correctAnswerIndex,
            selectedReasoningIndex: firstItem.correctReasoningIndex,
            usedAssistance: false
        )

        XCTAssertTrue(progress.isCompleted)
        XCTAssertFalse(progress.requiresReviewGrade, "非强制阻塞，直接自动按 Good 完成")
        XCTAssertEqual(session.statusRawValue, "completed")
        XCTAssertEqual(plan.status, "completed")
    }

    // 13. 突破验证候选规则：初窥、入门不进入自动候选，仅通晓且 >=45 分进入候选
    func testBreakthroughCandidateRulesFilterLowStageDebt() throws {
        let entryNode = KnowledgeNode(name: "Entry Node", domain: "Swift", isProvisional: false)
        let advancingNode = KnowledgeNode(name: "Advancing Node", domain: "Swift", isProvisional: false)
        let proficientNode = KnowledgeNode(name: "Proficient Node", domain: "Swift", isProvisional: false)
        let integratedNode = KnowledgeNode(name: "Integrated Node", domain: "Swift", isProvisional: false)

        container.mainContext.insert(entryNode)
        container.mainContext.insert(advancingNode)
        container.mainContext.insert(proficientNode)
        container.mainContext.insert(integratedNode)

        container.mainContext.insert(MasteryState(knowledgeNodeID: entryNode.id))
        container.mainContext.insert(MasteryState(knowledgeNodeID: advancingNode.id))
        container.mainContext.insert(MasteryState(knowledgeNodeID: proficientNode.id))
        container.mainContext.insert(MasteryState(knowledgeNodeID: integratedNode.id))
        try container.mainContext.save()
        appState.reload()

        // entryNode: 5分 (初窥)
        let ev1 = makeArtifactEvidence(kind: .exposure, daysAgo: 1, nodeID: entryNode.id)
        appState.applyArtifactEvidence(ev1)

        // advancingNode: 30分 (入门)
        for i in 0..<5 {
            let ev = makeArtifactEvidence(kind: .exercise, daysAgo: Double(i), nodeID: advancingNode.id)
            appState.applyArtifactEvidence(ev)
        }

        // proficientNode: 50分 (通晓且接近突破)
        let kinds: [EvidenceKind] = [.exposure, .explanation, .exercise, .project, .independentSolve]
        for (i, kind) in (0..<25).map({ ($0, kinds[$0 % kinds.count]) }) {
            let ev = makeArtifactEvidence(kind: kind, daysAgo: Double(i), nodeID: proficientNode.id)
            appState.applyArtifactEvidence(ev)
        }

        // integratedNode: 已认证融会
        for dim in MasteryDimension.allCases {
            let est = MasteryEstimate(
                knowledgeNodeID: integratedNode.id,
                dimension: dim,
                probability: 0.75,
                observationCount: 2,
                correctCount: 2,
                modelVersion: MasteryEstimator.modelVersion
            )
            container.mainContext.insert(est)
        }
        let obs = MasteryObservation(
            canonicalKey: "int-obs",
            sessionID: UUID(),
            itemID: UUID(),
            responseID: UUID(),
            knowledgeNodeID: integratedNode.id,
            dimension: .understanding,
            isCorrect: true,
            guessProbability: 0.25,
            slipProbability: 0.1,
            priorProbability: 0.5,
            predictedCorrectProbability: 0.75,
            posteriorProbability: 0.75,
            observedAt: .now,
            modelVersion: MasteryEstimator.modelVersion
        )
        container.mainContext.insert(obs)
        try container.mainContext.save()
        appState.reload()

        // 仅 proficientNode 应当属于 pendingVerification
        XCTAssertEqual(appState.pendingVerificationKnowledgeCount, 1)
        XCTAssertEqual(appState.domainAssessmentCandidates(for: "Swift").map(\.id), [proficientNode.id])
    }

    // 14. 5 知识点题包无论如何最多只允许 3 题硬上限
    func testFiveKnowledgeNodePackageHardCappedAtThreeResponses() async throws {
        var nodes: [KnowledgeNode] = []
        for i in 1...5 {
            let n = KnowledgeNode(name: "Node \(i)", domain: "Domain", isProvisional: false)
            container.mainContext.insert(n)
            container.mainContext.insert(MasteryState(knowledgeNodeID: n.id))
            nodes.append(n)
        }
        try container.mainContext.save()
        appState.reload()

        let session = AssessmentSession(knowledgeNodeID: nodes[0].id, kind: .baseline, generatorModelID: "test-model")
        container.mainContext.insert(session)
        appState.assessmentSessions.append(session)

        var items: [AssessmentItem] = []
        for (idx, n) in nodes.enumerated() {
            for q in 0..<2 {
                let pkgItem = AssessmentPackage.Item(
                    knowledgeNodeID: n.id,
                    tier: .application,
                    stem: "Node \(idx) Question \(q)",
                    answerOptions: ["A", "B", "C", "D"],
                    correctAnswerIndex: 0,
                    reasoningPrompt: "Reason",
                    reasoningOptions: ["R1", "R2", "R3", "R4"],
                    correctReasoningIndex: 0,
                    explanation: "Exp",
                    misconceptionTags: [],
                    sourceActivityIDs: []
                )
                let item = AssessmentItem(sessionID: session.id, item: pkgItem)
                container.mainContext.insert(item)
                appState.assessmentItems.append(item)
                items.append(item)
            }
        }
        session.presentedItemIDs = [items[0].id]
        try container.mainContext.save()
        appState.refreshDerivedState()

        // 故意让第 1 题答错，第 2 题答对，测试自适应引擎是否在 3 题时硬性截断
        var currentProgress: AssessmentProgress?
        for step in 0..<3 {
            let currentItem = try XCTUnwrap(appState.currentItem(for: session))
            let isCorrect = step > 0
            let ansIdx = isCorrect ? currentItem.correctAnswerIndex : (currentItem.correctAnswerIndex + 1) % 4
            currentProgress = try appState.recordAssessmentResponse(
                session: session,
                item: currentItem,
                selectedAnswerIndex: ansIdx,
                selectedReasoningIndex: currentItem.correctReasoningIndex,
                usedAssistance: false
            )
        }

        XCTAssertTrue(try XCTUnwrap(currentProgress).isCompleted, "达到 3 题硬上限必须结束 session")
        XCTAssertEqual(session.statusRawValue, "completed")
        XCTAssertEqual(appState.responses(for: session.id).count, 3)

        // 验证只有被测到的知识点生成直接 evidence，未抽到的知识点不受影响
        let measuredNodeIDs = Set(appState.responses(for: session.id).compactMap { resp in
            items.first(where: { $0.id == resp.itemID })?.knowledgeNodeID
        })
        XCTAssertEqual(measuredNodeIDs.count, 3)
        let generatedEvidence = appState.evidenceRecords.filter { $0.assessmentSessionID == session.id }
        XCTAssertEqual(Set(generatedEvidence.map(\.knowledgeNodeID)), measuredNodeIDs)
    }

    // 15. Artifact 成长在 Assessment 之后不被清零，且能继续增长
    func testArtifactGrowthPreservedAcrossAssessmentAndNotZeroed() throws {
        let state = try XCTUnwrap(appState.mastery(for: node.id))
        let kinds: [EvidenceKind] = [.exposure, .explanation, .exercise, .project, .independentSolve]
        for (i, kind) in (0..<20).map({ ($0, kinds[$0 % kinds.count]) }) {
            let ev = makeArtifactEvidence(kind: kind, daysAgo: Double(i), nodeID: node.id)
            appState.applyArtifactEvidence(ev)
        }

        let exposureBefore = state.vector.exposure
        let autonomyBefore = state.vector.autonomy
        XCTAssertGreaterThan(exposureBefore, 20)
        XCTAssertGreaterThan(autonomyBefore, 30)

        // 做一次只测 understanding/practice 的 assessment
        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 1)
        let item = items[0]
        _ = try appState.recordAssessmentResponse(
            session: session,
            item: item,
            selectedAnswerIndex: item.correctAnswerIndex,
            selectedReasoningIndex: item.correctReasoningIndex,
            usedAssistance: false
        )

        // 未测量的维度绝不能被清零，必须保留现有成长
        let stateAfter = try XCTUnwrap(appState.mastery(for: node.id))
        XCTAssertGreaterThan(stateAfter.vector.exposure, 0)
        XCTAssertGreaterThan(stateAfter.vector.autonomy, 0)
        XCTAssertGreaterThanOrEqual(stateAfter.vector.exposure, exposureBefore)
        XCTAssertGreaterThanOrEqual(stateAfter.vector.autonomy, autonomyBefore)

        // 之后再次产生新的 artifact 证据，currentComposite 仍然能继续自然成长
        let compositeBeforeNew = try XCTUnwrap(appState.readiness(for: node.id)).currentComposite
        let newEv = makeArtifactEvidence(kind: .independentSolve, daysAgo: 0, nodeID: node.id)
        appState.applyArtifactEvidence(newEv)
        let compositeAfterNew = try XCTUnwrap(appState.readiness(for: node.id)).currentComposite
        XCTAssertGreaterThan(compositeAfterNew, compositeBeforeNew)
    }

    // 16. 单题双 observation 真实流程下 snapshot.observationCount 必须为 1
    func testSingleQuestionWithTwoObservationsProducesObservationCountOne() throws {
        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 1)
        let item = items[0]
        _ = try appState.recordAssessmentResponse(
            session: session,
            item: item,
            selectedAnswerIndex: item.correctAnswerIndex,
            selectedReasoningIndex: item.correctReasoningIndex,
            usedAssistance: false
        )

        XCTAssertEqual(appState.masteryObservations.count, 2, "单题写入 primary + understanding 2 个 observation")
        let snapshot = try XCTUnwrap(appState.readiness(for: node.id))
        XCTAssertEqual(snapshot.observationCount, 1, "采样样本数必须严格按 unique response 计数")
    }

    // 17. Delayed Review 修改评价只更新 FSRS 记忆，不重复结算 XP / Evidence
    func testDelayedReviewGradeUpdateIdempotentAndRecalculatesFSRS() async throws {
        try appState.scheduleReview(for: node.id, scheduledAt: .now.addingTimeInterval(-10), reason: "到期")
        let plan = try XCTUnwrap(appState.reviewPlans.first(where: { $0.knowledgeNodeID == node.id }))

        let (session, items) = try setupAssessmentSession(nodeID: node.id, itemCount: 1, kind: .delayedReview, planID: plan.id)
        let firstItem = items[0]

        // 1. 自动以 Good 完成
        _ = try appState.recordAssessmentResponse(
            session: session,
            item: firstItem,
            selectedAnswerIndex: firstItem.correctAnswerIndex,
            selectedReasoningIndex: firstItem.correctReasoningIndex,
            usedAssistance: false
        )
        XCTAssertEqual(session.statusRawValue, "completed")
        XCTAssertEqual(appState.memoryReviewEvents.count, 1)
        XCTAssertEqual(appState.memoryReviewEvents[0].grade, .good)

        let initialEvCount = appState.evidenceRecords.count
        let initialLedgerCount = appState.scoreLedgerEntries.count
        let initialXP = appState.totalXP
        let memoryAfterGood = try XCTUnwrap(appState.memory(for: node.id))
        let difficultyAfterGood = memoryAfterGood.difficulty
        let stabilityAfterGood = memoryAfterGood.stability

        // 2. 用户在完成页修改为 Hard
        try appState.completeReviewAssessment(session: session, grade: .hard)

        XCTAssertEqual(appState.memoryReviewEvents.count, 1, "不得重复插入 review event")
        XCTAssertEqual(appState.memoryReviewEvents[0].grade, .hard)
        XCTAssertEqual(appState.evidenceRecords.count, initialEvCount, "不得重复生成 evidence")
        XCTAssertEqual(appState.scoreLedgerEntries.count, initialLedgerCount, "不得重复生成 ledger entry")
        XCTAssertEqual(appState.totalXP, initialXP, "不得重复发放 XP")

        let memoryAfterHard = try XCTUnwrap(appState.memory(for: node.id))
        XCTAssertNotEqual(memoryAfterHard.difficulty, difficultyAfterGood, "Hard 对应的难度应高于 Good")
        XCTAssertNotEqual(memoryAfterHard.stability, stabilityAfterGood, "Hard 对应的稳定性应与 Good 不同")

        // 3. 再次传入 Hard（幂等）
        try appState.updateReviewGrade(sessionID: session.id, grade: .hard)
        XCTAssertEqual(appState.memoryReviewEvents.count, 1)
    }

    // MARK: - Helpers

    private func makeArtifactEvidence(kind: EvidenceKind, daysAgo: Double, nodeID: UUID? = nil) -> EvidenceRecord {
        let targetNodeID = nodeID ?? node.id
        let date = Date.now.addingTimeInterval(-daysAgo * 86_400)
        let ev = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: targetNodeID,
            kind: kind,
            timestamp: date,
            summary: "研习记录 \(kind.title)",
            rationale: "学习产物沉淀",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.9,
            isVerified: true,
            fingerprint: "ev-\(UUID().uuidString)",
            origin: .artifact,
            verificationLevel: .artifactCandidate
        )
        container.mainContext.insert(ev)
        appState.evidenceRecords.append(ev)
        appState.evidenceByID[ev.id] = ev
        appState.evidenceByNodeID[targetNodeID, default: []].append(ev)
        return ev
    }

    private func setupAssessmentSession(
        nodeID: UUID,
        itemCount: Int,
        kind: AssessmentKind = .baseline,
        planID: UUID? = nil
    ) throws -> (AssessmentSession, [AssessmentItem]) {
        let session = AssessmentSession(
            knowledgeNodeID: nodeID,
            kind: kind,
            generatorModelID: "test-model",
            reviewPlanID: planID
        )
        container.mainContext.insert(session)
        appState.assessmentSessions.append(session)

        let tiers: [AssessmentTier] = [.application, .transfer, .foundational, .application]
        var items: [AssessmentItem] = []
        for i in 0..<itemCount {
            let pkgItem = AssessmentPackage.Item(
                knowledgeNodeID: nodeID,
                tier: tiers[i % tiers.count],
                stem: "情境题 \(i)",
                answerOptions: ["选项 A", "选项 B", "选项 C", "选项 D"],
                correctAnswerIndex: 0,
                reasoningPrompt: "理由题 \(i)",
                reasoningOptions: ["理由 1", "理由 2", "理由 3", "理由 4"],
                correctReasoningIndex: 0,
                explanation: "解析 \(i)",
                misconceptionTags: [],
                sourceActivityIDs: []
            )
            let item = AssessmentItem(sessionID: session.id, item: pkgItem)
            container.mainContext.insert(item)
            appState.assessmentItems.append(item)
            items.append(item)
        }
        session.presentedItemIDs = [items[0].id]
        try container.mainContext.save()
        appState.refreshDerivedState()
        return (session, items)
    }
}
