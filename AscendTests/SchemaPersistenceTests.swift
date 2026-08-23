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
        let source = SourceConfiguration(name: "Remote", kind: .remoteGitMarkdown, path: "/tmp/repo")
        source.lastSyncError = "fetch failed"
        let activity = ActivityEvent(
            sourceID: source.id,
            sourceKind: .remoteGitMarkdown,
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

        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<SourceConfiguration>()).first?.lastSyncError, "fetch failed")
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<ActivityEvent>()).first?.contentChangeHash, "content-change")
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<EvidenceRecord>()).first?.contentChangeHash, "content-change")
    }
}
