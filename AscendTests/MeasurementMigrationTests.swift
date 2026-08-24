import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class MeasurementMigrationTests: XCTestCase {
    func testExistingAnalysisIsNeverAcknowledgedWithoutConfirmation() throws {
        let suiteName = "MeasurementMigrationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(AppConstants.currentMeasurementSystemVersion - 1, forKey: AppConstants.measurementSystemVersionKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let container = PersistenceController.makeContainer(inMemory: true)
        container.mainContext.insert(KnowledgeNode(name: "Actor", domain: "Swift"))
        try container.mainContext.save()

        let appState = AppState(modelContainer: container, automationDefaults: defaults)

        XCTAssertTrue(appState.requiresMeasurementReset)
        XCTAssertEqual(
            defaults.integer(forKey: AppConstants.measurementSystemVersionKey),
            AppConstants.currentMeasurementSystemVersion - 1,
            "存在旧分析结果时不得静默写入新体系版本"
        )
    }

    func testEmptyStoreCanAcknowledgeCurrentMeasurementVersion() throws {
        let suiteName = "MeasurementMigrationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let appState = AppState(
            modelContainer: PersistenceController.makeContainer(inMemory: true),
            automationDefaults: defaults
        )

        XCTAssertFalse(appState.requiresMeasurementReset)
        XCTAssertEqual(defaults.integer(forKey: AppConstants.measurementSystemVersionKey), AppConstants.currentMeasurementSystemVersion)
    }

    func testConfirmationPreservesConfigurationAndRawActivitiesAndIsIdempotent() throws {
        let suiteName = "MeasurementMigrationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(1, forKey: AppConstants.measurementSystemVersionKey)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let container = PersistenceController.makeContainer(inMemory: true)
        let source = SourceConfiguration(name: "Notes", kind: .markdownDirectory, path: "/tmp/notes")
        let endpoint = AIEndpointProfile(name: "AI", baseURLString: "https://example.invalid/v1", selectedModelID: "mock")
        let activity = ActivityEvent(
            sourceID: source.id,
            sourceKind: .markdownDirectory,
            timestamp: .now,
            fingerprint: "raw-activity",
            title: "Actor note",
            sourceLocator: "/tmp/notes/actor.md",
            summary: "summary",
            excerpt: "excerpt",
            isProcessed: true
        )
        let node = KnowledgeNode(name: "Actor", domain: "Swift")
        let mastery = MasteryState(
            knowledgeNodeID: node.id,
            vector: MasteryVector(exposure: 80, understanding: 80, practice: 80, retention: 80, autonomy: 80),
            lifetimeXP: 800,
            highestStage: .connected
        )
        container.mainContext.insert(source)
        container.mainContext.insert(endpoint)
        container.mainContext.insert(activity)
        container.mainContext.insert(node)
        container.mainContext.insert(mastery)
        try container.mainContext.save()
        let appState = AppState(modelContainer: container, automationDefaults: defaults)

        XCTAssertTrue(appState.requiresMeasurementReset)
        XCTAssertEqual(appState.totalXP, 800, "确认前不得改变数据")
        XCTAssertTrue(activity.isProcessed)

        try appState.confirmMeasurementSystemReset()

        XCTAssertFalse(appState.requiresMeasurementReset)
        XCTAssertEqual(defaults.integer(forKey: AppConstants.measurementSystemVersionKey), AppConstants.currentMeasurementSystemVersion)
        XCTAssertEqual(appState.sources.map(\.id), [source.id])
        XCTAssertEqual(appState.endpointProfiles.map(\.id), [endpoint.id])
        XCTAssertEqual(appState.activityEvents.map(\.id), [activity.id])
        XCTAssertFalse(activity.isProcessed)
        XCTAssertTrue(appState.knowledgeNodes.isEmpty)
        XCTAssertTrue(appState.evidenceRecords.isEmpty)
        XCTAssertEqual(appState.totalXP, 0)

        try appState.confirmMeasurementSystemReset()
        XCTAssertEqual(appState.sources.count, 1)
        XCTAssertEqual(appState.activityEvents.count, 1)
        XCTAssertEqual(appState.totalXP, 0)
    }
}
