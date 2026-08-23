import SwiftData
import XCTest
@testable import Ascend

final class SchemaMigrationTests: XCTestCase {
    @MainActor
    func testV1SuggestionMigratesToV4WithOptionalEvidenceLink() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "migration.store")
        let suggestionID = UUID()

        do {
            let schema = Schema(versionedSchema: AscendSchemaV1.self)
            let configuration = ModelConfiguration("MigrationTest", schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            container.mainContext.insert(
                AscendSchemaV1.TaxonomySuggestion(
                    id: suggestionID,
                    suggestionType: "reviewEvidence",
                    proposedName: "Linux 进程",
                    rationale: "旧版本建议",
                    confidence: 0.7
                )
            )
            try container.mainContext.save()
        }

        let schema = Schema(versionedSchema: AscendSchemaV4.self)
        let configuration = ModelConfiguration("MigrationTest", schema: schema, url: storeURL)
        let migrated = try ModelContainer(
            for: schema,
            migrationPlan: AscendMigrationPlan.self,
            configurations: [configuration]
        )
        let suggestions = try migrated.mainContext.fetch(FetchDescriptor<TaxonomySuggestion>())
        let exclusions = try migrated.mainContext.fetch(FetchDescriptor<ActivityTrackingExclusion>())

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].id, suggestionID)
        XCTAssertNil(suggestions[0].evidenceID)
        XCTAssertTrue(exclusions.isEmpty)
    }

    @MainActor
    func testV2ActivitiesSurviveV4Migration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "migration-v2.store")
        let activityID = UUID()

        do {
            let schema = Schema(versionedSchema: AscendSchemaV2.self)
            let configuration = ModelConfiguration("MigrationV2Test", schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            container.mainContext.insert(
                ActivityEvent(
                    id: activityID,
                    sourceID: UUID(),
                    sourceKind: .markdownDirectory,
                    timestamp: .now,
                    fingerprint: "migration-activity",
                    title: "迁移笔记",
                    sourceLocator: "/notes/migration.md",
                    summary: "测试",
                    excerpt: "测试"
                )
            )
            try container.mainContext.save()
        }

        let schema = Schema(versionedSchema: AscendSchemaV4.self)
        let configuration = ModelConfiguration("MigrationV2Test", schema: schema, url: storeURL)
        let migrated = try ModelContainer(
            for: schema,
            migrationPlan: AscendMigrationPlan.self,
            configurations: [configuration]
        )

        let activities = try migrated.mainContext.fetch(FetchDescriptor<ActivityEvent>())
        XCTAssertEqual(activities.map(\.id), [activityID])
        XCTAssertEqual(try migrated.mainContext.fetchCount(FetchDescriptor<ActivityTrackingExclusion>()), 0)
    }

    @MainActor
    func testV3ChallengeSurvivesV4AutomationMigration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "migration-v3.store")
        let challengeID = UUID()

        do {
            let schema = Schema(versionedSchema: AscendSchemaV3.self)
            let configuration = ModelConfiguration("MigrationV3Test", schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            container.mainContext.insert(
                Challenge(
                    id: challengeID,
                    title: "旧版挑战",
                    challengeDescription: "迁移后仍应保留",
                    estimatedMinutes: 30,
                    knowledgeNodeIDs: [],
                    requirements: ["真实实据"],
                    rewardXP: 20
                )
            )
            try container.mainContext.save()
        }

        let schema = Schema(versionedSchema: AscendSchemaV4.self)
        let configuration = ModelConfiguration("MigrationV3Test", schema: schema, url: storeURL)
        let migrated = try ModelContainer(
            for: schema,
            migrationPlan: AscendMigrationPlan.self,
            configurations: [configuration]
        )

        XCTAssertEqual(try migrated.mainContext.fetch(FetchDescriptor<Challenge>()).map(\.id), [challengeID])
        XCTAssertEqual(try migrated.mainContext.fetchCount(FetchDescriptor<ChallengeAutomationState>()), 0)
        XCTAssertEqual(try migrated.mainContext.fetchCount(FetchDescriptor<RealmAdvancementEvent>()), 0)
    }
}
