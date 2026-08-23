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
        let edgeAB = KnowledgeEdge(sourceNodeID: nodeA, targetNodeID: nodeB, relation: .prerequisite, confidence: 0.95, origin: "ai")
        let checkAB = engine.canAddPrerequisite(sourceNodeID: nodeA, targetNodeID: nodeB, existingEdges: [])
        XCTAssertTrue(checkAB.canAdd)

        // 2. 自环拒绝 A -> A
        let checkSelfLoop = engine.canAddPrerequisite(sourceNodeID: nodeA, targetNodeID: nodeA, existingEdges: [edgeAB])
        XCTAssertFalse(checkSelfLoop.canAdd, "自环必须被拒绝")

        // 3. 重复边拒绝 A -> B
        let checkDuplicate = engine.canAddPrerequisite(sourceNodeID: nodeA, targetNodeID: nodeB, existingEdges: [edgeAB])
        XCTAssertFalse(checkDuplicate.canAdd, "重复前置边必须被拒绝")

        // 4. 建立 B -> C
        let edgeBC = KnowledgeEdge(sourceNodeID: nodeB, targetNodeID: nodeC, relation: .prerequisite, confidence: 0.95, origin: "ai")
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
        XCTAssertEqual(edge1.origin, "legacyUnknown", "未指定 origin 时必须真实保留 legacyUnknown")
        XCTAssertNil(edge1.createdAt, "未指定 createdAt 时必须保持 nil，不伪造当前时间")
    }

    // MARK: - 2. 拓扑就绪与阻塞计算

    func testPrerequisiteBlockedAndUnlockedLifecycle() {
        let engine = LearningTopologyEngine(prerequisiteThreshold: 60.0, masteredThreshold: 80.0)

        let forkID = UUID()
        let waitpidID = UUID()
        let ipcID = UUID()

        let edgeForkToIPC = KnowledgeEdge(sourceNodeID: forkID, targetNodeID: ipcID, relation: .prerequisite, confidence: 0.95, origin: "ai")
        let edgeWaitpidToIPC = KnowledgeEdge(sourceNodeID: waitpidID, targetNodeID: ipcID, relation: .prerequisite, confidence: 0.95, origin: "ai")
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
        let schema = Schema(versionedSchema: AscendSchemaV8.self)
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
        let schema = Schema(versionedSchema: AscendSchemaV8.self)
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
        let schema = Schema(versionedSchema: AscendSchemaV8.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let nodeA = KnowledgeNode(name: "A", domain: "测试")
        let nodeB = KnowledgeNode(name: "B", domain: "测试")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)

        // 已经存在 A -> B
        let existingEdge = KnowledgeEdge(sourceNodeID: nodeA.id, targetNodeID: nodeB.id, relation: .prerequisite, confidence: 0.9, origin: "ai")
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

    // MARK: - 4. FSRS 实时 Retention 衰减导致 DAG 状态变化与 Re-block

    @MainActor
    func testFsrsCurrentReadinessDecayReBlocksDownstreamConcept() throws {
        let schema = Schema(versionedSchema: AscendSchemaV8.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let fork = KnowledgeNode(name: "fork", domain: "系统编程")
        let ipc = KnowledgeNode(name: "IPC", domain: "系统编程")
        container.mainContext.insert(fork)
        container.mainContext.insert(ipc)

        // 构造非记忆维度总和 = 0.10*55 + 0.25*55 + 0.25*55 + 0.20*55 = 44 分
        // t0 时加上 0.20*100 = 20 分，总分 = 64 分 >= 60（融会）
        let forkMastery = MasteryState(
            knowledgeNodeID: fork.id,
            vector: MasteryVector(exposure: 55, understanding: 55, practice: 55, retention: 100, autonomy: 55),
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
            lapses: 0,
            learningState: .review
        )
        container.mainContext.insert(forkMemory)

        let edge = KnowledgeEdge(sourceNodeID: fork.id, targetNodeID: ipc.id, relation: .prerequisite, confidence: 0.95, origin: "ai")
        container.mainContext.insert(edge)

        try container.mainContext.save()
        appState.reload()

        // 1. 在 t0 时（now = lastReviewAt），retention=100 -> fork currentComposite = 44 + 0.20*100 = 64 >= 60 -> IPC 就绪
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let forkCompositeT0 = appState.currentComposite(for: fork.id, now: t0)
        XCTAssertGreaterThanOrEqual(forkCompositeT0, 60.0, "t0 时前置掌握度应达到融会门槛 (60)")

        let statusT0 = appState.topologyStatus(for: ipc.id, now: t0)
        XCTAssertEqual(statusT0, .readyToLearn(satisfiedPrerequisites: [fork.id]))

        let unlockedT0 = appState.unlockedNextConcepts(for: fork.id, now: t0)
        XCTAssertTrue(unlockedT0.contains { $0.id == ipc.id }, "t0 时 IPC 应在 fork 的 unlockedNextConcepts 中")

        // 2. 经过 200 天后（now = t0 + 200 days），FSRS retrievability 衰减至较低值，
        // fork currentComposite 下降至 44 + 0.20*retention < 60！
        let t200 = Date(timeIntervalSince1970: 1_700_000_000 + 200 * 86_400)
        let forkCompositeT200 = appState.currentComposite(for: fork.id, now: t200)
        XCTAssertLessThan(forkCompositeT200, 60.0, "200天后前置掌握度应跌破 60 分")

        // 断言：IPC 从 readyToLearn 重新转变为 blocked！
        let statusT200 = appState.topologyStatus(for: ipc.id, now: t200)
        if case .blocked(let missing) = statusT200 {
            XCTAssertEqual(missing, [fork.id], "IPC 必须被重新阻断")
        } else {
            XCTFail("IPC 应该重新转为 blocked 状态")
        }

        // 断言：unlockedNextConcepts 不再包含 IPC！
        let unlockedT200 = appState.unlockedNextConcepts(for: fork.id, now: t200)
        XCTAssertFalse(unlockedT200.contains { $0.id == ipc.id }, "衰减后 unlockedNextConcepts 绝不能包含受阻的 IPC")

        // 断言：绝不修改历史 XP 和最高境界！
        XCTAssertEqual(forkMastery.lifetimeXP, 500, "历史 XP 不受 FSRS 衰减影响")
        XCTAssertEqual(forkMastery.highestStage, .integrated, "最高境界不受 FSRS 衰减影响")
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

    // MARK: - 6. 下一境候选建议完整闭环测试（fork + waitpid -> IPC）

    @MainActor
    func testNextConceptApprovalWithPrerequisitesAndMasteryStateZero() async throws {
        let schema = Schema(versionedSchema: AscendSchemaV8.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let fork = KnowledgeNode(name: "fork", domain: "系统编程")
        let waitpid = KnowledgeNode(name: "waitpid", domain: "系统编程")
        container.mainContext.insert(fork)
        container.mainContext.insert(waitpid)
        try container.mainContext.save()
        appState.reload()

        let envelope = AnalysisEnvelope(
            sessionSummary: "研习多进程编程模型",
            evidence: [],
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: nil,
            possibleNextConcepts: [
                NextConceptSuggestion(
                    proposedName: "进程间通信（IPC）",
                    domain: "系统编程",
                    prerequisiteNames: ["fork", "waitpid"],
                    rationale: "掌握 fork 与 waitpid 后，建议探索进程间通信管道",
                    confidence: 0.9
                )
            ]
        )

        // 1. 应用 AI 分析
        try appState.apply(envelope: envelope, to: [], createsAggregateResults: true)

        // 验证未批准前：IPC 不存在，XP 仍为 0
        XCTAssertEqual(appState.knowledgeNodes.count, 2, "未批准前 IPC 绝不能被直接创建")
        XCTAssertEqual(appState.totalXP, 0, "AI 建议绝不能增加 XP")

        XCTAssertEqual(appState.taxonomySuggestions.count, 1)
        guard let suggestion = appState.taxonomySuggestions.first else {
            XCTFail("应生成 nextConcept 建议")
            return
        }
        XCTAssertEqual(suggestion.suggestionType, "nextConcept")
        XCTAssertEqual(suggestion.proposedName, "进程间通信（IPC）")
        XCTAssertEqual(Set(suggestion.prerequisiteNodeIDs), Set([fork.id, waitpid.id]), "前置 IDs 必须结构化解析保存")

        // 2. 批准建议
        appState.approveSuggestion(suggestion)

        // 验证批准后：
        // - IPC KnowledgeNode 存在
        let ipcNode = appState.knowledgeNodes.first { $0.name == "进程间通信（IPC）" }
        XCTAssertNotNil(ipcNode)
        XCTAssertEqual(ipcNode?.isProvisional, false)

        // - IPC MasteryState.zero 存在
        let ipcMastery = appState.mastery(for: ipcNode!.id)
        XCTAssertNotNil(ipcMastery)
        XCTAssertEqual(ipcMastery?.vector, .zero)
        XCTAssertEqual(ipcMastery?.lifetimeXP, 0)

        // - fork -> IPC 与 waitpid -> IPC 前置边存在
        let forkToIPC = appState.knowledgeEdges.first { $0.sourceNodeID == fork.id && $0.targetNodeID == ipcNode!.id }
        let waitpidToIPC = appState.knowledgeEdges.first { $0.sourceNodeID == waitpid.id && $0.targetNodeID == ipcNode!.id }
        XCTAssertNotNil(forkToIPC)
        XCTAssertNotNil(waitpidToIPC)
        XCTAssertEqual(forkToIPC?.relation, .prerequisite)
        XCTAssertEqual(forkToIPC?.origin, "userConfirmed")
        XCTAssertNotNil(forkToIPC?.confirmedAt)
        XCTAssertEqual(forkToIPC?.rationale, "掌握 fork 与 waitpid 后，建议探索进程间通信管道")
        XCTAssertEqual(waitpidToIPC?.origin, "userConfirmed")

        // - XP 仍为 0，不创建 Evidence
        XCTAssertEqual(appState.totalXP, 0)
        XCTAssertEqual(appState.evidenceRecords.count, 0)

        // 3. 验证 IPC 可以进入 recommendationSnapshots / 今日修炼（若前置已就绪）
        // 模拟 fork 和 waitpid 达到融会 (70 分)
        let forkM = MasteryState(knowledgeNodeID: fork.id, vector: MasteryVector(exposure: 70, understanding: 70, practice: 70, retention: 70, autonomy: 70), confidence: 80, stabilityDays: 5, lastEvidenceAt: .now, lifetimeXP: 100, highestStage: .integrated)
        let waitM = MasteryState(knowledgeNodeID: waitpid.id, vector: MasteryVector(exposure: 70, understanding: 70, practice: 70, retention: 70, autonomy: 70), confidence: 80, stabilityDays: 5, lastEvidenceAt: .now, lifetimeXP: 100, highestStage: .integrated)
        container.mainContext.insert(forkM)
        container.mainContext.insert(waitM)
        try container.mainContext.save()
        appState.reload()

        let recs = appState.learningRecommendations
        XCTAssertTrue(recs.contains { $0.knowledgeNodeID == ipcNode?.id && $0.type == .nextConcept }, "前置达标后 IPC 必须作为下一境出现在学习推荐中")
    }

    // MARK: - 7. Export / Import 往返保持 highestStage 与 Edge Provenance

    @MainActor
    func testLosslessHighestStageAndTopologyRoundTrip() async throws {
        let schema = Schema(versionedSchema: AscendSchemaV8.self)
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

    // MARK: - 8. NextConcept 审核原子性与 Preflight 零部分提交

    @MainActor
    func testNextConceptApprovalAtomicRollbackWhenPrerequisiteIsDeleted() throws {
        let schema = Schema(versionedSchema: AscendSchemaV8.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let validNode = KnowledgeNode(name: "fork", domain: "系统编程")
        container.mainContext.insert(validNode)
        try container.mainContext.save()
        appState.reload()

        let deletedNodeID = UUID() // 不存在的节点 ID
        let suggestion = TaxonomySuggestion(
            suggestionType: "nextConcept",
            proposedName: "进程间通信（IPC）",
            rationale: "研习 IPC",
            confidence: 0.9,
            targetDomain: "系统编程",
            prerequisiteNodeIDs: [validNode.id, deletedNodeID]
        )
        container.mainContext.insert(suggestion)
        try container.mainContext.save()
        appState.reload()

        XCTAssertEqual(appState.knowledgeNodes.count, 1)

        // 尝试批准：其中一个前置不存在
        appState.approveSuggestion(suggestion)

        // 验证：零部分提交！
        // 1. IPC 节点不能被创建
        XCTAssertEqual(appState.knowledgeNodes.count, 1)
        XCTAssertNil(appState.knowledgeNodes.first { $0.name == "进程间通信（IPC）" })
        // 2. 不能创建任何 edge
        XCTAssertEqual(appState.knowledgeEdges.count, 0)
        // 3. 不能创建任何 mastery state
        XCTAssertEqual(appState.masteryStates.count, 0)
        // 4. suggestion 保持 pending
        XCTAssertEqual(suggestion.status, "pending")
        XCTAssertTrue(appState.statusMessage?.contains("前置知识点不存在") == true)
    }

    @MainActor
    func testNextConceptApprovalAtomicRollbackWhenPrerequisiteCreatesCycle() throws {
        let schema = Schema(versionedSchema: AscendSchemaV8.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let nodeA = KnowledgeNode(name: "基础概念A", domain: "测试")
        let nodeB = KnowledgeNode(name: "进阶概念B", domain: "测试")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)

        // 已存在 B -> A 的前置依赖
        let edgeBA = KnowledgeEdge(
            sourceNodeID: nodeB.id,
            targetNodeID: nodeA.id,
            relation: .prerequisite,
            confidence: 0.9,
            origin: "userConfirmed"
        )
        container.mainContext.insert(edgeBA)
        try container.mainContext.save()
        appState.reload()

        // 建议收录 A 作为 target，但将 B 设为其前置（若创建 A -> B 会导致 A -> B -> A 循环依赖）
        // 这里 proposedName 为 "进阶概念B"（已存在），前置为 nodeA.id
        // 即试图创建 A -> B，与已有的 B -> A 成环！
        let cycleSuggestion = TaxonomySuggestion(
            suggestionType: "nextConcept",
            proposedName: "进阶概念B",
            rationale: "测试成环",
            confidence: 0.9,
            targetDomain: "测试",
            prerequisiteNodeIDs: [nodeA.id]
        )
        container.mainContext.insert(cycleSuggestion)
        try container.mainContext.save()
        appState.reload()

        // 尝试批准
        appState.approveSuggestion(cycleSuggestion)

        // 验证：零部分提交！
        XCTAssertEqual(appState.knowledgeEdges.count, 1, "成环的 Edge 绝不能被插入")
        XCTAssertEqual(cycleSuggestion.status, "pending")
        XCTAssertTrue(appState.statusMessage?.contains("循环依赖") == true)
    }
}
