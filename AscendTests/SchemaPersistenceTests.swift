import SwiftData
import XCTest
@testable import Ascend

final class SchemaPersistenceTests: XCTestCase {
    @MainActor
    func testCurrentSchemaPersistsMarkdownReliabilityAndMemoryFields() throws {
        let schema = Schema(versionedSchema: AscendSchemaV9.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let source = SourceConfiguration(
            name: "Remote",
            kind: .remoteGitRepository,
            path: "/tmp/repo",
            analyzeMarkdown: true,
            analyzeCode: false,
            remoteURLString: "https://example.invalid/repo.git"
        )
        source.lastUpstreamReference = "origin/main"
        source.lastSyncError = "fetch failed"
        let activity = ActivityEvent(
            sourceID: source.id,
            sourceKind: .remoteGitRepository,
            timestamp: .now,
            fingerprint: "remote-event",
            contentChangeHash: "content-change",
            title: "Linux",
            sourceLocator: "/tmp/repo#sha:linux.md",
            summary: "Remote Git Markdown",
            excerpt: "fork"
        )
        let evidence = EvidenceRecord(
            activityID: activity.id,
            knowledgeNodeID: UUID(),
            kind: .explanation,
            timestamp: .now,
            summary: "fork",
            rationale: "笔记说明",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.9,
            isVerified: true,
            fingerprint: "remote-event-node",
            contentChangeHash: "content-change"
        )
        let nodeID = evidence.knowledgeNodeID
        let reviewedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let memory = MemoryState(
            knowledgeNodeID: nodeID,
            difficulty: 4.2,
            stability: 8.5,
            retrievability: 0.87,
            lastReviewAt: reviewedAt,
            nextReviewAt: reviewedAt.addingTimeInterval(7 * 86_400),
            scheduledDays: 7,
            reps: 3,
            lapses: 1,
            learningSteps: 0,
            learningState: .review
        )
        let reviewEvent = MemoryReviewEvent(
            knowledgeNodeID: nodeID,
            evidenceID: evidence.id,
            canonicalKey: "content-change:\(nodeID.uuidString)",
            grade: .good,
            reviewedAt: reviewedAt,
            source: "verifiedEvidence"
        )
        container.mainContext.insert(source)
        container.mainContext.insert(activity)
        container.mainContext.insert(evidence)
        container.mainContext.insert(memory)
        container.mainContext.insert(reviewEvent)
        try container.mainContext.save()

        let persistedSource = try container.mainContext.fetch(FetchDescriptor<SourceConfiguration>()).first
        XCTAssertEqual(persistedSource?.lastSyncError, "fetch failed")
        XCTAssertEqual(persistedSource?.lastUpstreamReference, "origin/main")
        XCTAssertEqual(persistedSource?.remoteURLString, "https://example.invalid/repo.git")
        XCTAssertEqual(persistedSource?.analyzeMarkdown, true)
        XCTAssertEqual(persistedSource?.analyzeCode, false)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<ActivityEvent>()).first?.contentChangeHash, "content-change")
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<EvidenceRecord>()).first?.contentChangeHash, "content-change")
        let persistedMemory = try container.mainContext.fetch(FetchDescriptor<MemoryState>()).first
        XCTAssertEqual(persistedMemory?.difficulty, 4.2)
        XCTAssertEqual(persistedMemory?.stability, 8.5)
        XCTAssertEqual(persistedMemory?.reps, 3)
        XCTAssertEqual(persistedMemory?.lapses, 1)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<MemoryReviewEvent>()).first?.grade, .good)
    }

    @MainActor
    func testExportBundleIncludesKnowledgeEdgesAndMemoryHistory() async throws {
        let schema = Schema(versionedSchema: AscendSchemaV9.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let appState = AppState(modelContainer: container)

        let nodeA = KnowledgeNode(name: "并发模型", domain: "系统编程")
        let nodeB = KnowledgeNode(name: "Actor 隔离", domain: "系统编程")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)

        // 插入一条未指定 provenance 的旧边
        let edge = KnowledgeEdge(
            sourceNodeID: nodeA.id,
            targetNodeID: nodeB.id,
            relationRawValue: "前置",
            confidence: 0.95
        )
        container.mainContext.insert(edge)

        XCTAssertEqual(edge.origin, "legacyUnknown", "未设定 provenance 时应真实呈现为 legacyUnknown")
        XCTAssertNil(edge.createdAt, "未设定 createdAt 时不得虚构当前时间")

        let source = SourceConfiguration(
            name: "代码主仓",
            kind: .remoteGitRepository,
            path: "/path/to/repo",
            isEnabled: true,
            analyzeWorkingTree: true,
            analyzeMarkdown: true,
            analyzeCode: true,
            authorFilter: "Developer",
            remoteURLString: "https://git.example.com/repo.git",
            ignorePatternsText: "*.tmp\nbuild/"
        )
        source.lastScannedAt = Date(timeIntervalSince1970: 1_700_000_000)
        source.lastCursor = "commit-sha-abcdef"
        source.lastUpstreamReference = "origin/main"
        container.mainContext.insert(source)

        let activityID = UUID()
        let evidenceID = UUID()
        let evidenceTimestamp = Date(timeIntervalSince1970: 1_700_000_100)
        let evidence = EvidenceRecord(
            id: evidenceID,
            activityID: activityID,
            knowledgeNodeID: nodeA.id,
            kind: .exercise,
            timestamp: evidenceTimestamp,
            summary: "完成了 Actor 隔离测试",
            rationale: "独立重构并发模块",
            difficulty: 3.5,
            independence: 0.9,
            aiConfidence: 0.92,
            isVerified: true,
            fingerprint: "git-commit-12345",
            contentChangeHash: "hash-998877"
        )
        container.mainContext.insert(evidence)

        let initialCanonicalKey = appState.evidenceScoringKey(evidence)

        let mastery = MasteryState(
            knowledgeNodeID: nodeA.id,
            vector: MasteryVector(exposure: 80, understanding: 75, practice: 90, retention: 85, autonomy: 70),
            confidence: 90,
            stabilityDays: 14,
            lastEvidenceAt: evidenceTimestamp,
            lifetimeXP: 350,
            highestStage: .integrated
        )
        container.mainContext.insert(mastery)

        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_200)
        let memoryEvent = MemoryReviewEvent(
            knowledgeNodeID: nodeA.id,
            evidenceID: evidenceID,
            canonicalKey: initialCanonicalKey,
            grade: .good,
            reviewedAt: reviewedAt,
            source: "verifiedEvidence"
        )
        container.mainContext.insert(memoryEvent)

        let ledgerEntry = ScoreLedgerEntry(
            evidenceID: evidenceID,
            knowledgeNodeID: nodeA.id,
            timestamp: evidenceTimestamp,
            previousComposite: 50,
            newComposite: 75,
            xpAwarded: 25,
            reason: "首次掌握"
        )
        container.mainContext.insert(ledgerEntry)
        try container.mainContext.save()
        appState.reload()

        // 导出
        let exportedData = try appState.exportJSON()
        XCTAssertFalse(exportedData.isEmpty)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportBundle = try decoder.decode(ExportBundle.self, from: exportedData)
        XCTAssertEqual(exportBundle.formatVersion, 2)
        XCTAssertTrue(exportBundle.masteryStates.isEmpty)
        XCTAssertTrue(exportBundle.evidence.isEmpty)
        XCTAssertTrue(exportBundle.scoreLedgerEntries?.isEmpty == true)

        // 清库 & 重新导入
        try await appState.importJSON(exportedData)

        // v2 和旧版导入都只恢复配置，不恢复旧分析、评分、XP、记忆或拓扑。
        XCTAssertTrue(appState.knowledgeNodes.isEmpty)
        XCTAssertTrue(appState.knowledgeEdges.isEmpty)
        XCTAssertTrue(appState.evidenceRecords.isEmpty)
        XCTAssertTrue(appState.memoryStates.isEmpty)
        XCTAssertEqual(appState.totalXP, 0)

        // 6. 验证 SourceConfiguration
        let importedSource = appState.sources.first { $0.id == source.id }
        XCTAssertNotNil(importedSource)
        XCTAssertEqual(importedSource?.lastCursor, "commit-sha-abcdef")
        XCTAssertEqual(importedSource?.lastUpstreamReference, "origin/main")
        XCTAssertEqual(importedSource?.ignorePatternsText, "*.tmp\nbuild/")
        XCTAssertEqual(importedSource?.lastScannedAt, Date(timeIntervalSince1970: 1_700_000_000))
    }

    @MainActor
    func testRealDiskStorePersistenceForCoreModels() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let storeURL = tempDir.appendingPathComponent("AscendDiskTest.sqlite")
        let schema = Schema(versionedSchema: AscendSchemaV9.self)
        let config = ModelConfiguration("AscendDiskTest", schema: schema, url: storeURL)

        let nodeID = UUID()
        let evidenceID = UUID()
        let activityID = UUID()
        let targetNodeID = UUID()
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)

        // 阶段 1：写入真实磁盘
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext

            let node = KnowledgeNode(id: nodeID, name: "虚拟内存", domain: "操作系统")
            let targetNode = KnowledgeNode(id: targetNodeID, name: "页面置换", domain: "操作系统")
            context.insert(node)
            context.insert(targetNode)

            let evidence = EvidenceRecord(
                id: evidenceID,
                activityID: activityID,
                knowledgeNodeID: nodeID,
                kind: .project,
                timestamp: reviewedAt,
                summary: "实现 LRU 置换算法",
                rationale: "代码提交与分析",
                difficulty: 4.0,
                independence: 1.0,
                aiConfidence: 0.95,
                isVerified: true,
                fingerprint: "disk-fp-001",
                contentChangeHash: "disk-hash-001"
            )
            context.insert(evidence)

            let mastery = MasteryState(
                knowledgeNodeID: nodeID,
                vector: MasteryVector(exposure: 80, understanding: 75, practice: 90, retention: 85, autonomy: 70),
                confidence: 92,
                stabilityDays: 14,
                lastEvidenceAt: reviewedAt,
                lifetimeXP: 1250,
                highestStage: .connected
            )
            context.insert(mastery)

            let edge = KnowledgeEdge(
                sourceNodeID: nodeID,
                targetNodeID: targetNodeID,
                relation: .prerequisite,
                confidence: 0.98,
                rationale: "虚拟内存是页面置换的前置先导概念",
                origin: "userConfirmed",
                createdAt: reviewedAt,
                confirmedAt: reviewedAt
            )
            context.insert(edge)

            let memory = MemoryState(
                knowledgeNodeID: nodeID,
                difficulty: 3.8,
                stability: 14.5,
                retrievability: 0.92,
                lastReviewAt: reviewedAt,
                nextReviewAt: reviewedAt.addingTimeInterval(14 * 86_400),
                scheduledDays: 14,
                reps: 4,
                lapses: 0,
                learningSteps: 0,
                learningState: .review
            )
            context.insert(memory)

            let reviewEvent = MemoryReviewEvent(
                knowledgeNodeID: nodeID,
                evidenceID: evidenceID,
                canonicalKey: "disk-hash-001:\(nodeID.uuidString)",
                grade: .good,
                reviewedAt: reviewedAt,
                source: "verifiedEvidence"
            )
            context.insert(reviewEvent)

            try context.save()
        }

        // 阶段 2：以全新 ModelContainer 从磁盘重新加载，验证所有模型持久化完备性
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext

            // 1. KnowledgeNode
            let nodes = try context.fetch(FetchDescriptor<KnowledgeNode>())
            XCTAssertEqual(nodes.count, 2)
            let fetchedNode = nodes.first { $0.id == nodeID }
            XCTAssertEqual(fetchedNode?.name, "虚拟内存")
            XCTAssertEqual(fetchedNode?.domain, "操作系统")

            // 2. EvidenceRecord
            let evidences = try context.fetch(FetchDescriptor<EvidenceRecord>())
            XCTAssertEqual(evidences.count, 1)
            let fetchedEvidence = evidences.first
            XCTAssertEqual(fetchedEvidence?.id, evidenceID)
            XCTAssertEqual(fetchedEvidence?.knowledgeNodeID, nodeID)
            XCTAssertEqual(fetchedEvidence?.summary, "实现 LRU 置换算法")
            XCTAssertEqual(fetchedEvidence?.difficulty, 4.0)
            XCTAssertEqual(fetchedEvidence?.isVerified, true)

            // 3. MasteryState (包含 lifetimeXP 与 highestStage)
            let masteries = try context.fetch(FetchDescriptor<MasteryState>())
            XCTAssertEqual(masteries.count, 1)
            let fetchedMastery = masteries.first
            XCTAssertEqual(fetchedMastery?.knowledgeNodeID, nodeID)
            XCTAssertEqual(fetchedMastery?.lifetimeXP, 1250)
            XCTAssertEqual(fetchedMastery?.highestStage, .connected)
            XCTAssertEqual(fetchedMastery?.vector.practice, 90)

            // 4. KnowledgeEdge (包含 relation, origin, rationale)
            let edges = try context.fetch(FetchDescriptor<KnowledgeEdge>())
            XCTAssertEqual(edges.count, 1)
            let fetchedEdge = edges.first
            XCTAssertEqual(fetchedEdge?.sourceNodeID, nodeID)
            XCTAssertEqual(fetchedEdge?.targetNodeID, targetNodeID)
            XCTAssertEqual(fetchedEdge?.relation, .prerequisite)
            XCTAssertEqual(fetchedEdge?.origin, "userConfirmed")
            XCTAssertEqual(fetchedEdge?.rationale, "虚拟内存是页面置换的前置先导概念")

            // 5. MemoryState (FSRS 状态正常持久化)
            let memoryStates = try context.fetch(FetchDescriptor<MemoryState>())
            XCTAssertEqual(memoryStates.count, 1)
            let fetchedMemory = memoryStates.first
            XCTAssertEqual(fetchedMemory?.knowledgeNodeID, nodeID)
            XCTAssertEqual(fetchedMemory?.difficulty, 3.8)
            XCTAssertEqual(fetchedMemory?.stability, 14.5)
            XCTAssertEqual(fetchedMemory?.reps, 4)
            XCTAssertEqual(fetchedMemory?.learningState, .review)

            // 6. MemoryReviewEvent
            let reviewEvents = try context.fetch(FetchDescriptor<MemoryReviewEvent>())
            XCTAssertEqual(reviewEvents.count, 1)
            let fetchedEvent = reviewEvents.first
            XCTAssertEqual(fetchedEvent?.knowledgeNodeID, nodeID)
            XCTAssertEqual(fetchedEvent?.evidenceID, evidenceID)
            XCTAssertEqual(fetchedEvent?.grade, .good)
            XCTAssertEqual(fetchedEvent?.canonicalKey, "disk-hash-001:\(nodeID.uuidString)")
        }
    }
}
