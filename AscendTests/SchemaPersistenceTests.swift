import SwiftData
import XCTest
@testable import Ascend

final class SchemaPersistenceTests: XCTestCase {
    @MainActor
    func testCurrentSchemaPersistsMarkdownReliabilityAndMemoryFields() throws {
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
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
        let schema = Schema(versionedSchema: AscendSchemaV7.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let appState = AppState(modelContainer: container)

        let nodeA = KnowledgeNode(name: "并发模型", domain: "系统编程")
        let nodeB = KnowledgeNode(name: "Actor 隔离", domain: "系统编程")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)

        let edge = KnowledgeEdge(
            sourceNodeID: nodeA.id,
            targetNodeID: nodeB.id,
            relationRawValue: "前置",
            confidence: 0.95
        )
        container.mainContext.insert(edge)

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

        // 清库 & 重新导入
        try await appState.importJSON(exportedData)

        // 1. 验证 KnowledgeNodes
        XCTAssertEqual(appState.knowledgeNodes.count, 2)
        let importedNodeA = appState.knowledgeNodes.first { $0.id == nodeA.id }
        XCTAssertNotNil(importedNodeA)

        // 2. 验证 KnowledgeEdges
        XCTAssertEqual(appState.knowledgeEdges.count, 1)
        XCTAssertEqual(appState.knowledgeEdges.first?.sourceNodeID, nodeA.id)
        XCTAssertEqual(appState.knowledgeEdges.first?.targetNodeID, nodeB.id)
        XCTAssertEqual(appState.knowledgeEdges.first?.relationRawValue, "前置")
        XCTAssertEqual(appState.knowledgeEdges.first?.confidence, 0.95)

        // 3. 验证 XP & Highest Stage
        XCTAssertEqual(appState.totalXP, 350)
        let importedMastery = appState.mastery(for: nodeA.id)
        XCTAssertEqual(importedMastery?.lifetimeXP, 350)
        XCTAssertEqual(importedMastery?.highestStage, .integrated)

        // 4. 验证 Evidence 属性与 Canonical Identity 无损
        XCTAssertEqual(appState.evidenceRecords.count, 1)
        guard let importedEvidence = appState.evidenceRecords.first else {
            XCTFail("Missing imported evidence")
            return
        }
        XCTAssertEqual(importedEvidence.id, evidenceID)
        XCTAssertEqual(importedEvidence.activityID, activityID)
        XCTAssertEqual(importedEvidence.difficulty, 3.5)
        XCTAssertEqual(importedEvidence.independence, 0.9)
        XCTAssertEqual(importedEvidence.aiConfidence, 0.92)
        XCTAssertEqual(importedEvidence.fingerprint, "git-commit-12345")
        XCTAssertEqual(importedEvidence.contentChangeHash, "hash-998877")
        XCTAssertEqual(appState.evidenceScoringKey(importedEvidence), initialCanonicalKey, "Evidence canonical key 必须保持一致")

        // 5. 验证 FSRS MemoryState 确定性恢复
        let memory = appState.memory(for: nodeA.id)
        XCTAssertNotNil(memory, "FSRS MemoryState 必须在 import 后通过 replayMemory 确定性重建")
        XCTAssertGreaterThan(memory?.stability ?? 0, 0)
        XCTAssertGreaterThan(memory?.difficulty ?? 0, 0)
        XCTAssertEqual(memory?.reps, 1)
        XCTAssertGreaterThan(memory?.nextReviewAt.timeIntervalSince1970 ?? 0, reviewedAt.timeIntervalSince1970)

        // 6. 验证 SourceConfiguration
        let importedSource = appState.sources.first { $0.id == source.id }
        XCTAssertNotNil(importedSource)
        XCTAssertEqual(importedSource?.lastCursor, "commit-sha-abcdef")
        XCTAssertEqual(importedSource?.lastUpstreamReference, "origin/main")
        XCTAssertEqual(importedSource?.ignorePatternsText, "*.tmp\nbuild/")
        XCTAssertEqual(importedSource?.lastScannedAt, Date(timeIntervalSince1970: 1_700_000_000))
    }
}
