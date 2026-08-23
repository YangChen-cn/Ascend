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

        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let memoryEvent = MemoryReviewEvent(
            knowledgeNodeID: nodeA.id,
            evidenceID: nil,
            canonicalKey: "review:\(nodeA.id.uuidString)",
            grade: .easy,
            reviewedAt: reviewedAt,
            source: "explicitGrade"
        )
        container.mainContext.insert(memoryEvent)

        let ledgerEntry = ScoreLedgerEntry(
            evidenceID: UUID(),
            knowledgeNodeID: nodeA.id,
            timestamp: reviewedAt,
            previousComposite: 10,
            newComposite: 25,
            xpAwarded: 15,
            reason: "首次掌握"
        )
        container.mainContext.insert(ledgerEntry)
        try container.mainContext.save()
        appState.reload()

        // 导出
        let exportedData = try appState.exportJSON()
        XCTAssertFalse(exportedData.isEmpty)

        // 导入
        try await appState.importJSON(exportedData)

        XCTAssertEqual(appState.knowledgeNodes.count, 2)
        XCTAssertEqual(appState.knowledgeEdges.count, 1)
        XCTAssertEqual(appState.knowledgeEdges.first?.sourceNodeID, nodeA.id)
        XCTAssertEqual(appState.knowledgeEdges.first?.targetNodeID, nodeB.id)
        XCTAssertEqual(appState.knowledgeEdges.first?.relationRawValue, "前置")

        XCTAssertEqual(appState.memoryReviewEvents.count, 1)
        XCTAssertEqual(appState.memoryReviewEvents.first?.grade, .easy)
        XCTAssertEqual(appState.memoryReviewEvents.first?.knowledgeNodeID, nodeA.id)

        XCTAssertEqual(appState.scoreLedgerEntries.count, 1)
        XCTAssertEqual(appState.scoreLedgerEntries.first?.xpAwarded, 15)
    }
}
