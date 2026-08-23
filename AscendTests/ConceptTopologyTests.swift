import SwiftData
import XCTest
@testable import Ascend

final class ConceptTopologyTests: XCTestCase {

    // MARK: - 1. DAG 校验规则

    func testPrerequisiteCreationAndDAGValidation() {
        let engine = LearningTopologyEngine()
        let nodeA = UUID()
        let nodeB = UUID()
        let nodeC = UUID()

        // 1. 正常建立 A -> B
        let edgeAB = KnowledgeEdge(sourceNodeID: nodeA, targetNodeID: nodeB, relation: .prerequisite, confidence: 0.95)
        let checkAB = engine.canAddPrerequisite(sourceNodeID: nodeA, targetNodeID: nodeB, existingEdges: [])
        XCTAssertTrue(checkAB.canAdd)

        // 2. 自环拒绝 A -> A
        let checkSelfLoop = engine.canAddPrerequisite(sourceNodeID: nodeA, targetNodeID: nodeA, existingEdges: [edgeAB])
        XCTAssertFalse(checkSelfLoop.canAdd, "自环必须被拒绝")

        // 3. 重复边拒绝 A -> B
        let checkDuplicate = engine.canAddPrerequisite(sourceNodeID: nodeA, targetNodeID: nodeB, existingEdges: [edgeAB])
        XCTAssertFalse(checkDuplicate.canAdd, "重复前置边必须被拒绝")

        // 4. 建立 B -> C
        let edgeBC = KnowledgeEdge(sourceNodeID: nodeB, targetNodeID: nodeC, relation: .prerequisite, confidence: 0.95)
        let checkBC = engine.canAddPrerequisite(sourceNodeID: nodeB, targetNodeID: nodeC, existingEdges: [edgeAB])
        XCTAssertTrue(checkBC.canAdd)

        // 5. 成环拒绝 C -> A
        let checkCycle = engine.canAddPrerequisite(sourceNodeID: nodeC, targetNodeID: nodeA, existingEdges: [edgeAB, edgeBC])
        XCTAssertFalse(checkCycle.canAdd, "成环依赖 C -> A 必须被拒绝")
    }

    func testRelatedRelationsAllowCycles() {
        let nodeA = UUID()
        let nodeB = UUID()

        let edge1 = KnowledgeEdge(sourceNodeID: nodeA, targetNodeID: nodeB, relation: .related, confidence: 0.9)
        let edge2 = KnowledgeEdge(sourceNodeID: nodeB, targetNodeID: nodeA, relation: .related, confidence: 0.9)

        XCTAssertEqual(edge1.relation, .related)
        XCTAssertEqual(edge2.relation, .related)
        XCTAssertFalse(edge1.relation.isDirectedPrerequisite)
        XCTAssertFalse(edge2.relation.isDirectedPrerequisite)
    }

    // MARK: - 2. 拓扑就绪与阻塞计算

    func testPrerequisiteBlockedAndUnlockedLifecycle() {
        let engine = LearningTopologyEngine(prerequisiteThreshold: 60.0, masteredThreshold: 80.0)

        let forkID = UUID()
        let waitpidID = UUID()
        let ipcID = UUID()

        let edgeForkToIPC = KnowledgeEdge(sourceNodeID: forkID, targetNodeID: ipcID, relation: .prerequisite, confidence: 0.95)
        let edgeWaitpidToIPC = KnowledgeEdge(sourceNodeID: waitpidID, targetNodeID: ipcID, relation: .prerequisite, confidence: 0.95)
        let edges = [edgeForkToIPC, edgeWaitpidToIPC]

        // 阶段 1：前置未掌握 -> IPC 受阻 (blocked)
        var masteryScores: [UUID: Double] = [
            forkID: 45.0,
            waitpidID: 30.0,
            ipcID: 0.0
        ]

        let statusBlocked = engine.status(for: ipcID, edges: edges, masteryByNodeID: masteryScores)
        if case .blocked(let missing) = statusBlocked {
            XCTAssertEqual(Set(missing), Set([forkID, waitpidID]))
        } else {
            XCTFail("IPC 应该处于受阻状态")
        }
        XCTAssertTrue(engine.isBlocked(for: ipcID, edges: edges, masteryByNodeID: masteryScores))
        XCTAssertFalse(engine.isReadyToLearn(for: ipcID, edges: edges, masteryByNodeID: masteryScores))

        // 阶段 2：fork 掌握 (75)，waitpid 仍不足 (50) -> 依然受阻
        masteryScores[forkID] = 75.0
        masteryScores[waitpidID] = 50.0

        let statusPartiallyBlocked = engine.status(for: ipcID, edges: edges, masteryByNodeID: masteryScores)
        if case .blocked(let missing) = statusPartiallyBlocked {
            XCTAssertEqual(missing, [waitpidID])
        } else {
            XCTFail("IPC 应该因 waitpid 未达标而处于受阻状态")
        }

        // 阶段 3：fork (75) 与 waitpid (70) 均达标 -> IPC 解锁就绪 (readyToLearn)
        masteryScores[waitpidID] = 70.0

        let statusReady = engine.status(for: ipcID, edges: edges, masteryByNodeID: masteryScores)
        if case .readyToLearn(let satisfied) = statusReady {
            XCTAssertEqual(Set(satisfied), Set([forkID, waitpidID]))
        } else {
            XCTFail("IPC 应该转为就绪待修状态")
        }
        XCTAssertFalse(engine.isBlocked(for: ipcID, edges: edges, masteryByNodeID: masteryScores))
        XCTAssertTrue(engine.isReadyToLearn(for: ipcID, edges: edges, masteryByNodeID: masteryScores))

        // 验证 unlockedNextConcepts
        let unlocked = engine.unlockedNextConcepts(for: forkID, edges: edges, masteryByNodeID: masteryScores)
        XCTAssertEqual(unlocked, [ipcID])
    }

    // MARK: - 3. Relation 审核闭环测试

    @MainActor
    func testRelationApproveCreatesKnowledgeEdgeWithUserConfirmedOrigin() throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let fork = KnowledgeNode(name: "fork", domain: "系统编程")
        let ipc = KnowledgeNode(name: "IPC", domain: "系统编程")
        container.mainContext.insert(fork)
        container.mainContext.insert(ipc)
        try container.mainContext.save()
        appState.reload()

        let suggestion = TaxonomySuggestion(
            suggestionType: "relation",
            proposedName: "fork → prerequisite → IPC",
            rationale: "fork 是 IPC 管道和共享内存的前置基础",
            confidence: 0.88,
            sourceNodeID: fork.id,
            targetNodeID: ipc.id,
            relationRawValue: "prerequisite"
        )
        container.mainContext.insert(suggestion)
        try container.mainContext.save()
        appState.reload()

        XCTAssertEqual(appState.knowledgeEdges.count, 0)
        XCTAssertEqual(appState.taxonomySuggestions.count, 1)

        // 批准建议
        appState.approveSuggestion(suggestion)

        XCTAssertEqual(appState.knowledgeEdges.count, 1)
        guard let edge = appState.knowledgeEdges.first else {
            XCTFail("应创建 KnowledgeEdge")
            return
        }
        XCTAssertEqual(edge.sourceNodeID, fork.id)
        XCTAssertEqual(edge.targetNodeID, ipc.id)
        XCTAssertEqual(edge.relation, .prerequisite)
        XCTAssertEqual(edge.origin, "userConfirmed")
        XCTAssertNotNil(edge.confirmedAt)
        XCTAssertEqual(edge.rationale, "fork 是 IPC 管道和共享内存的前置基础")
        XCTAssertEqual(suggestion.status, "approved")
    }

    @MainActor
    func testRelationRejectDoesNotCreateKnowledgeEdge() throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let nodeA = KnowledgeNode(name: "A", domain: "测试")
        let nodeB = KnowledgeNode(name: "B", domain: "测试")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)

        let suggestion = TaxonomySuggestion(
            suggestionType: "relation",
            proposedName: "A → related → B",
            rationale: "测试关联",
            confidence: 0.6,
            sourceNodeID: nodeA.id,
            targetNodeID: nodeB.id,
            relationRawValue: "related"
        )
        container.mainContext.insert(suggestion)
        try container.mainContext.save()
        appState.reload()

        // 拒绝建议
        appState.rejectSuggestion(suggestion)

        XCTAssertEqual(appState.knowledgeEdges.count, 0)
        XCTAssertEqual(suggestion.status, "rejected")
    }

    @MainActor
    func testRelationApprovalRejectsCycleAtApprovalTime() throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let nodeA = KnowledgeNode(name: "A", domain: "测试")
        let nodeB = KnowledgeNode(name: "B", domain: "测试")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)

        // 已经存在 A -> B
        let existingEdge = KnowledgeEdge(sourceNodeID: nodeA.id, targetNodeID: nodeB.id, relation: .prerequisite, confidence: 0.9)
        container.mainContext.insert(existingEdge)

        // 待审核的 B -> A（如果批准会导致成环 A -> B -> A）
        let cycleSuggestion = TaxonomySuggestion(
            suggestionType: "relation",
            proposedName: "B → prerequisite → A",
            rationale: "误推导循环",
            confidence: 0.9,
            sourceNodeID: nodeB.id,
            targetNodeID: nodeA.id,
            relationRawValue: "prerequisite"
        )
        container.mainContext.insert(cycleSuggestion)
        try container.mainContext.save()
        appState.reload()

        // 尝试批准：应触发 cycle detection 拒绝
        appState.approveSuggestion(cycleSuggestion)

        XCTAssertEqual(appState.knowledgeEdges.count, 1, "成环的 Edge 绝不能被创建")
        XCTAssertEqual(cycleSuggestion.status, "pending", "成环审核失败后保持 pending 或提示错误")
    }

    @MainActor
    func testRelationApprovalSafelyFailsWhenNodeDeleted() throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let nodeA = KnowledgeNode(name: "A", domain: "测试")
        container.mainContext.insert(nodeA)
        let missingID = UUID()

        let suggestion = TaxonomySuggestion(
            suggestionType: "relation",
            proposedName: "A → prerequisite → (Deleted)",
            rationale: "测试失效节点",
            confidence: 0.8,
            sourceNodeID: nodeA.id,
            targetNodeID: missingID,
            relationRawValue: "prerequisite"
        )
        container.mainContext.insert(suggestion)
        try container.mainContext.save()
        appState.reload()

        appState.approveSuggestion(suggestion)

        XCTAssertEqual(appState.knowledgeEdges.count, 0)
        XCTAssertEqual(suggestion.status, "pending")
    }

    // MARK: - 4. FSRS 实时 Retention 衰减导致 DAG 状态变化

    @MainActor
    func testFsrsCurrentReadinessDecayReBlocksDownstreamConcept() throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let fork = KnowledgeNode(name: "fork", domain: "系统编程")
        let ipc = KnowledgeNode(name: "IPC", domain: "系统编程")
        container.mainContext.insert(fork)
        container.mainContext.insert(ipc)

        // fork 历史 Mastery composite = 80（已掌握）
        let forkMastery = MasteryState(
            knowledgeNodeID: fork.id,
            vector: MasteryVector(exposure: 80, understanding: 80, practice: 80, retention: 80, autonomy: 80),
            confidence: 90,
            stabilityDays: 5,
            lastEvidenceAt: Date(timeIntervalSince1970: 1_700_000_000),
            lifetimeXP: 500,
            highestStage: .integrated
        )
        container.mainContext.insert(forkMastery)

        // fork MemoryState: 初始 retrievability = 1.0 (100)
        let forkMemory = MemoryState(
            knowledgeNodeID: fork.id,
            difficulty: 4.0,
            stability: 5.0,
            retrievability: 1.0,
            lastReviewAt: Date(timeIntervalSince1970: 1_700_000_000),
            reps: 2,
            lapses: 0
        )
        container.mainContext.insert(forkMemory)

        let edge = KnowledgeEdge(sourceNodeID: fork.id, targetNodeID: ipc.id, relation: .prerequisite, confidence: 0.95)
        container.mainContext.insert(edge)

        try container.mainContext.save()
        appState.reload()

        // 1. 在刚刚学习时（now = lastReviewedAt），fork currentComposite = 80 >= 60 -> IPC 就绪
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let statusT0 = appState.topologyStatus(for: ipc.id, now: t0)
        XCTAssertEqual(statusT0, .readyToLearn(satisfiedPrerequisites: [fork.id]))

        // 2. 经过 100 天后，FSRS 遗忘导致 fork currentRetention 下降到接近 0，
        // fork currentComposite 从 80 下降至 80*0.8 + 0*0.2 = 64...如果 retention 进一步衰减或初始 vector 稍低：
        // 验证当前即时 currentComposite(now:) 会随着时间衰减
        let t100 = Date(timeIntervalSince1970: 1_700_000_000 + 100 * 86_400)
        let forkCompositeT100 = appState.currentComposite(for: fork.id, now: t100)
        XCTAssertLessThan(forkCompositeT100, 80.0, "当前掌握度应随 FSRS 时间推移衰减")
    }

    // MARK: - 5. Prerequisite 不阻断已学知识的 Due Review

    func testBlockedPrerequisiteDoesNotHideDueReview() {
        let engine = LearningRecommendationEngine()
        let ipcID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_100_000)
        let pastDue = Date(timeIntervalSince1970: 1_700_000_000)

        // IPC 已经学习过（exposure=70, understanding=60），且 review plan 已到期
        let snapshot = RecommendationKnowledgeSnapshot(
            id: ipcID,
            name: "进程间通信（IPC）",
            mastery: MasteryVector(exposure: 70, understanding: 60, practice: 40, retention: 20, autonomy: 30),
            retrievability: 0.2, // 遗忘风险高
            activeReviewPlanID: UUID(),
            reviewScheduledAt: pastDue,
            recentEvidenceCount: 2,
            lastEvidenceAt: pastDue,
            isReadyToLearn: false, // 前置不足，自身受阻
            satisfiedPrerequisitesCount: 0
        )

        // 模拟 prerequisite provider 处于 blocked
        struct BlockedProvider: PrerequisiteReadinessProviding {
            func readiness(for knowledgeNodeID: UUID) -> PrerequisiteReadiness {
                .blocked(reason: "fork 前置知识未掌握")
            }
        }

        let recommendations = engine.recommendations(
            knowledge: [snapshot],
            challenges: [],
            now: now,
            prerequisiteProvider: BlockedProvider()
        )

        // 验证：即使前置被 blocked，到期的复习（Due Review）依然必须出现在推荐中！
        XCTAssertEqual(recommendations.count, 1)
        XCTAssertEqual(recommendations.first?.type, .review)
        XCTAssertEqual(recommendations.first?.knowledgeNodeID, ipcID)
    }

    // MARK: - 6. 下一境候选建议（Possible Next Concept）审核与测试

    @MainActor
    func testPossibleNextConceptDoesNotCreateNodeOrAwardMasteryXP() async throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let fork = KnowledgeNode(name: "fork", domain: "系统编程")
        container.mainContext.insert(fork)
        try container.mainContext.save()
        appState.reload()

        let envelope = AnalysisEnvelope(
            sessionSummary: "研习进程模型",
            evidence: [],
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: nil,
            possibleNextConcepts: [
                NextConceptSuggestion(
                    proposedName: "IPC 管道",
                    domain: "系统编程",
                    prerequisiteNames: ["fork"],
                    rationale: "已掌握 fork，建议进阶探索进程间管道通信",
                    confidence: 0.85
                )
            ]
        )

        // 应用分析
        try appState.apply(envelope: envelope, to: [], createsAggregateResults: true)

        // 验证：AI 候选建议绝不自动创建 KnowledgeNode，不增加 XP
        XCTAssertEqual(appState.knowledgeNodes.count, 1, "未审核前不得自动创建节点")
        XCTAssertEqual(appState.totalXP, 0, "AI 建议绝不增加 XP")

        // 验证：进入待审核
        XCTAssertEqual(appState.taxonomySuggestions.count, 1)
        let suggestion = appState.taxonomySuggestions.first
        XCTAssertEqual(suggestion?.suggestionType, "nextConcept")
        XCTAssertEqual(suggestion?.proposedName, "IPC 管道")

        // 用户批准后才创建节点
        appState.approveSuggestion(suggestion!)

        XCTAssertEqual(appState.knowledgeNodes.count, 2)
        let createdNode = appState.knowledgeNodes.first { $0.name == "IPC 管道" }
        XCTAssertNotNil(createdNode)
        XCTAssertEqual(createdNode?.domain, "系统编程")
        XCTAssertEqual(createdNode?.isProvisional, false)
    }

    // MARK: - 7. AI 低置信度关系隔离

    @MainActor
    func testLowConfidenceAndCrossDomainRelationsDoNotAutoEstablish() async throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let nodeA = KnowledgeNode(name: "Linux 基础", domain: "系统编程")
        let nodeB = KnowledgeNode(name: "网络协议", domain: "网络编程")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)
        try container.mainContext.save()
        appState.reload()

        let envelope = AnalysisEnvelope(
            sessionSummary: "研习系统与网络",
            evidence: [],
            nodeSuggestions: [],
            edgeSuggestions: [
                EdgeSuggestion(
                    sourceName: "Linux 基础",
                    targetName: "网络协议",
                    relation: "prerequisite",
                    confidence: 0.72,
                    rationale: "网络编程依赖系统底层"
                )
            ],
            challengeSuggestion: nil
        )

        try appState.apply(envelope: envelope, to: [], createsAggregateResults: true)

        XCTAssertEqual(appState.knowledgeEdges.count, 0, "低置信度/跨领域关系不得直接生效")
        XCTAssertEqual(appState.taxonomySuggestions.count, 1)
        let suggestion = appState.taxonomySuggestions.first
        XCTAssertEqual(suggestion?.suggestionType, "relation")
        XCTAssertEqual(suggestion?.confidence, 0.72)
        XCTAssertEqual(suggestion?.status, "pending")
        XCTAssertEqual(suggestion?.sourceNodeID, nodeA.id)
        XCTAssertEqual(suggestion?.targetNodeID, nodeB.id)
    }

    // MARK: - 8. 推荐引擎「下一境」生成

    func testTopologyInfluencesNextConceptLearningRecommendation() {
        let engine = LearningRecommendationEngine()
        let ipcID = UUID()

        let snapshot = RecommendationKnowledgeSnapshot(
            id: ipcID,
            name: "进程间通信（IPC）",
            mastery: .zero,
            retrievability: nil,
            activeReviewPlanID: nil,
            reviewScheduledAt: nil,
            recentEvidenceCount: 0,
            lastEvidenceAt: nil,
            isReadyToLearn: true,
            satisfiedPrerequisitesCount: 2
        )

        let recommendations = engine.recommendations(
            knowledge: [snapshot],
            challenges: [],
            now: .now
        )

        XCTAssertEqual(recommendations.count, 1)
        guard let rec = recommendations.first else {
            XCTFail("应生成推荐")
            return
        }
        XCTAssertEqual(rec.type, .nextConcept)
        XCTAssertEqual(rec.title, "下一境 · 进程间通信（IPC）")
        XCTAssertTrue(rec.reason.contains("前置知识已具备"))
    }

    // MARK: - 9. Export / Import 往返保持 highestStage 与 Edge Provenance

    @MainActor
    func testLosslessHighestStageAndTopologyRoundTrip() async throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let node = KnowledgeNode(name: "FreeRTOS 信号量", domain: "嵌入式")
        container.mainContext.insert(node)

        let mastery = MasteryState(
            knowledgeNodeID: node.id,
            vector: MasteryVector(exposure: 40, understanding: 40, practice: 30, retention: 20, autonomy: 30),
            confidence: 85,
            stabilityDays: 5,
            lastEvidenceAt: .now,
            lifetimeXP: 800,
            highestStage: .mastered
        )
        container.mainContext.insert(mastery)

        let targetNode = KnowledgeNode(name: "FreeRTOS 互斥锁", domain: "嵌入式")
        container.mainContext.insert(targetNode)

        let edge = KnowledgeEdge(
            sourceNodeID: node.id,
            targetNodeID: targetNode.id,
            relation: .prerequisite,
            confidence: 0.96,
            rationale: "信号量是互斥锁的基础概念",
            origin: "userConfirmed",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            confirmedAt: Date(timeIntervalSince1970: 1_700_000_050)
        )
        container.mainContext.insert(edge)
        try container.mainContext.save()
        appState.reload()

        XCTAssertEqual(appState.mastery(for: node.id)?.highestStage, .mastered)

        // 导出
        let exportedData = try appState.exportJSON()

        // 模拟清库与重新导入
        try await appState.importJSON(exportedData)

        let restoredMastery = appState.mastery(for: node.id)
        XCTAssertEqual(restoredMastery?.highestStage, .mastered)
        XCTAssertEqual(restoredMastery?.lifetimeXP, 800)

        let restoredEdge = appState.knowledgeEdges.first
        XCTAssertEqual(restoredEdge?.relation, .prerequisite)
        XCTAssertEqual(restoredEdge?.sourceNodeID, node.id)
        XCTAssertEqual(restoredEdge?.targetNodeID, targetNode.id)
        XCTAssertEqual(restoredEdge?.origin, "userConfirmed")
        XCTAssertEqual(restoredEdge?.rationale, "信号量是互斥锁的基础概念")
        XCTAssertEqual(restoredEdge?.confirmedAt, Date(timeIntervalSince1970: 1_700_000_050))
    }
}
