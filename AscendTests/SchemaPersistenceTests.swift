import SwiftData
import XCTest
@testable import Ascend

final class SchemaPersistenceTests: XCTestCase {
    @MainActor
    func testCurrentSchemaPersistsMarkdownReliabilityFields() throws {
        let schema = Schema(versionedSchema: AscendSchemaV6.self)
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
        container.mainContext.insert(source)
        container.mainContext.insert(activity)
        container.mainContext.insert(evidence)
        try container.mainContext.save()

        let persistedSource = try container.mainContext.fetch(FetchDescriptor<SourceConfiguration>()).first
        XCTAssertEqual(persistedSource?.lastSyncError, "fetch failed")
        XCTAssertEqual(persistedSource?.lastUpstreamReference, "origin/main")
        XCTAssertEqual(persistedSource?.remoteURLString, "https://example.invalid/repo.git")
        XCTAssertEqual(persistedSource?.analyzeMarkdown, true)
        XCTAssertEqual(persistedSource?.analyzeCode, false)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<ActivityEvent>()).first?.contentChangeHash, "content-change")
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<EvidenceRecord>()).first?.contentChangeHash, "content-change")
    }
}
