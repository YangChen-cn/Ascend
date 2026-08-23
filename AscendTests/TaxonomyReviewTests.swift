import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class TaxonomyReviewTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!

    override func setUp() async throws {
        let schema = Schema([
            AIEndpointProfile.self,
            SourceConfiguration.self,
            ActivityEvent.self,
            EvidenceRecord.self,
            KnowledgeNode.self,
            KnowledgeEdge.self,
            MasteryState.self,
            ScoreLedgerEntry.self,
            TaxonomySuggestion.self,
            Challenge.self,
            DailyDigest.self,
            AnalysisRun.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        appState = AppState(modelContainer: container)
    }

    override func tearDown() async throws {
        container = nil
        appState = nil
    }

    func testApproveNewNodeSuggestionRemovesProvisionalFlag() {
        let node = KnowledgeNode(name: "Swift Concurrency", domain: "Swift", isProvisional: true)
        let suggestion = TaxonomySuggestion(
            suggestionType: "newNode",
            proposedName: node.name,
            relatedNodeID: node.id,
            rationale: "Found new Swift Concurrency usage",
            confidence: 0.92
        )
        appState.modelContainer.mainContext.insert(node)
        appState.modelContainer.mainContext.insert(suggestion)
        try? appState.modelContainer.mainContext.save()
        appState.reload()

        appState.approveSuggestion(suggestion)

        XCTAssertFalse(node.isProvisional)
        XCTAssertEqual(suggestion.status, "approved")
    }

    func testApproveReviewEvidenceAwardsXPAndVerifiesEvidence() {
        let node = KnowledgeNode(name: "SwiftData", domain: "Persistence", isProvisional: false)
        let state = MasteryState(knowledgeNodeID: node.id)
        let evidence = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: node.id,
            kind: .project,
            timestamp: .now,
            summary: "Implemented SwiftData model",
            rationale: "Used @Model macro",
            difficulty: 1.0,
            independence: 1.0,
            aiConfidence: 0.75,
            isVerified: false,
            fingerprint: "test-evidence-1"
        )
        let suggestion = TaxonomySuggestion(
            suggestionType: "reviewEvidence",
            proposedName: node.name,
            relatedNodeID: node.id,
            rationale: "Low confidence match",
            confidence: 0.75
        )

        appState.modelContainer.mainContext.insert(node)
        appState.modelContainer.mainContext.insert(state)
        appState.modelContainer.mainContext.insert(evidence)
        appState.modelContainer.mainContext.insert(suggestion)
        try? appState.modelContainer.mainContext.save()
        appState.reload()

        appState.approveSuggestion(suggestion)

        XCTAssertTrue(evidence.isVerified)
        XCTAssertEqual(suggestion.status, "approved")
        XCTAssertGreaterThan(state.lifetimeXP, 0)
        XCTAssertGreaterThan(state.composite, 0)
    }

    func testRejectSuggestionDeletesUnverifiedEvidence() {
        let node = KnowledgeNode(name: "Docker", domain: "DevOps", isProvisional: false)
        let evidence = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: node.id,
            kind: .exposure,
            timestamp: .now,
            summary: "Touched Dockerfile",
            rationale: "Uncertain activity",
            difficulty: 1.0,
            independence: 1.0,
            aiConfidence: 0.60,
            isVerified: false,
            fingerprint: "test-evidence-2"
        )
        let suggestion = TaxonomySuggestion(
            suggestionType: "reviewEvidence",
            proposedName: node.name,
            relatedNodeID: node.id,
            rationale: "Uncertain",
            confidence: 0.60
        )

        appState.modelContainer.mainContext.insert(node)
        appState.modelContainer.mainContext.insert(evidence)
        appState.modelContainer.mainContext.insert(suggestion)
        try? appState.modelContainer.mainContext.save()
        appState.reload()

        appState.rejectSuggestion(suggestion)

        XCTAssertEqual(suggestion.status, "rejected")
        XCTAssertFalse(appState.evidenceRecords.contains(where: { $0.id == evidence.id }))
    }

    func testMergeSuggestionPointsEvidenceToTargetNode() {
        let targetNode = KnowledgeNode(name: "SwiftUI State", domain: "SwiftUI", isProvisional: false)
        let targetState = MasteryState(knowledgeNodeID: targetNode.id)
        let tempNode = KnowledgeNode(name: "Binding", domain: "待分类", isProvisional: true)
        let evidence = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: tempNode.id,
            kind: .explanation,
            timestamp: .now,
            summary: "Explained Two-way Binding",
            rationale: "Related to SwiftUI State",
            difficulty: 1.0,
            independence: 1.0,
            aiConfidence: 0.70,
            isVerified: false,
            fingerprint: "test-evidence-3"
        )
        let suggestion = TaxonomySuggestion(
            suggestionType: "reviewEvidence",
            proposedName: tempNode.name,
            relatedNodeID: tempNode.id,
            rationale: "Maybe SwiftUI State",
            confidence: 0.70
        )

        appState.modelContainer.mainContext.insert(targetNode)
        appState.modelContainer.mainContext.insert(targetState)
        appState.modelContainer.mainContext.insert(tempNode)
        appState.modelContainer.mainContext.insert(evidence)
        appState.modelContainer.mainContext.insert(suggestion)
        try? appState.modelContainer.mainContext.save()
        appState.reload()

        appState.mergeSuggestion(suggestion, into: targetNode.id)

        XCTAssertEqual(suggestion.status, "merged")
        XCTAssertEqual(evidence.knowledgeNodeID, targetNode.id)
        XCTAssertTrue(evidence.isVerified)
        XCTAssertGreaterThan(targetState.lifetimeXP, 0)
    }

    func testSourceDescriptorAuthorFilterEncoding() throws {
        let descriptor = SourceDescriptor(
            id: UUID(),
            name: "Repo",
            kind: .gitRepository,
            path: "/path/to/repo",
            analyzeWorkingTree: true,
            authorFilter: "dev@example.com",
            ignorePatterns: [".git"],
            lastScannedAt: nil,
            lastCursor: nil
        )

        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(SourceDescriptor.self, from: data)

        XCTAssertEqual(decoded.authorFilter, "dev@example.com")
        XCTAssertEqual(decoded.name, "Repo")
    }
}
