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

    // MARK: - 3. 学习推荐引擎接入「下一境」

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

    // MARK: - 4. AI 低置信度关系隔离进入 TaxonomySuggestion

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
                // 跨领域且低置信度关系
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

        // 执行应用 envelope
        try appState.apply(envelope: envelope, to: [], createsAggregateResults: true)

        // 验证：不应直接插入 KnowledgeEdge
        XCTAssertEqual(appState.knowledgeEdges.count, 0, "低置信度/跨领域关系不得直接生效")

        // 验证：应生成待审核建议
        XCTAssertEqual(appState.taxonomySuggestions.count, 1)
        let suggestion = appState.taxonomySuggestions.first
        XCTAssertEqual(suggestion?.suggestionType, "relation")
        XCTAssertEqual(suggestion?.confidence, 0.72)
        XCTAssertEqual(suggestion?.status, "pending")
    }

    // MARK: - 5. Export / Import 往返保持 highestStage 与 Edge 关系一致

    @MainActor
    func testLosslessHighestStageAndTopologyRoundTrip() async throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        let node = KnowledgeNode(name: "FreeRTOS 信号量", domain: "嵌入式")
        container.mainContext.insert(node)

        // 曾经达到“通达”境界 (level 6)，但当前掌握度因遗忘降低为 35 (入门)
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
            confidence: 0.96
        )
        container.mainContext.insert(edge)
        try container.mainContext.save()
        appState.reload()

        XCTAssertEqual(appState.mastery(for: node.id)?.highestStage, .mastered)

        // 导出
        let exportedData = try appState.exportJSON()

        // 模拟清库与重新导入
        try await appState.importJSON(exportedData)

        // 验证 highestStage 依然是 .mastered，绝不降级为当前 composite (33.5) 对应的 .advancing
        let restoredMastery = appState.mastery(for: node.id)
        XCTAssertEqual(restoredMastery?.highestStage, .mastered, "恢复后最高境界必须保持为历史最高 .mastered")
        XCTAssertEqual(restoredMastery?.lifetimeXP, 800)

        // 验证 edge 关系保持
        let restoredEdge = appState.knowledgeEdges.first
        XCTAssertEqual(restoredEdge?.relation, .prerequisite)
        XCTAssertEqual(restoredEdge?.sourceNodeID, node.id)
        XCTAssertEqual(restoredEdge?.targetNodeID, targetNode.id)
    }
}
