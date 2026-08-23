import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class DomainManagementTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!

    override func setUp() async throws {
        let schema = Schema([
            AIEndpointProfile.self,
            SourceConfiguration.self,
            ActivityEvent.self,
            ActivityTrackingExclusion.self,
            EvidenceRecord.self,
            KnowledgeNode.self,
            KnowledgeEdge.self,
            MasteryState.self,
            ScoreLedgerEntry.self,
            TaxonomySuggestion.self,
            ReviewPlan.self,
            MemoryState.self,
            MemoryReviewEvent.self,
            Challenge.self,
            ChallengeAutomationState.self,
            RealmAdvancementEvent.self,
            AutomationReceipt.self,
            AnalysisBatchSummary.self,
            AnalysisBatchActivityLink.self,
            DailyDigest.self,
            AnalysisRun.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        appState = AppState(modelContainer: container)
    }

    override func tearDown() async throws {
        appState = nil
        container = nil
    }

    func testRenameAndMergeDomainsPreserveNodesAndXP() throws {
        let englishNode = KnowledgeNode(name: "听力", domain: "English")
        let linuxNode = KnowledgeNode(name: "进程", domain: "嵌入式 Linux")
        let englishState = MasteryState(knowledgeNodeID: englishNode.id, lifetimeXP: 120)
        let linuxState = MasteryState(knowledgeNodeID: linuxNode.id, lifetimeXP: 230)
        insert(englishNode, englishState, linuxNode, linuxState)

        try appState.renameDomain("English", to: "英语")
        try appState.mergeDomain("英语", into: "嵌入式 Linux")

        XCTAssertEqual(appState.domainProgress.count, 1)
        XCTAssertEqual(appState.domainProgress.first?.name, "嵌入式 Linux")
        XCTAssertEqual(appState.domainProgress.first?.knowledgeCount, 2)
        XCTAssertEqual(appState.domainProgress.first?.xp, 350)
        XCTAssertEqual(appState.nodes(inDomain: "嵌入式 Linux").map(\.id).sorted(), [englishNode.id, linuxNode.id].sorted())
    }

    func testDeletingDomainCanPreserveKnowledgeInUncategorized() throws {
        let node = KnowledgeNode(name: "课程第一章", domain: "操作系统课程")
        let state = MasteryState(knowledgeNodeID: node.id, lifetimeXP: 80)
        let evidence = makeEvidence(nodeID: node.id)
        insert(node, state, evidence)

        try appState.deleteDomain("操作系统课程", strategy: .moveKnowledgeToUncategorized)

        XCTAssertTrue(appState.nodes(inDomain: "操作系统课程").isEmpty)
        XCTAssertEqual(appState.nodes(inDomain: "待分类").map(\.id), [node.id])
        XCTAssertEqual(appState.evidenceRecords.map(\.id), [evidence.id])
        XCTAssertEqual(appState.mastery(for: node.id)?.lifetimeXP, 80)
    }

    func testPermanentDomainDeletionCleansOnlyTargetDomainDerivedData() throws {
        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .manual,
            timestamp: .now,
            fingerprint: "delete-domain-activity",
            title: "领域学习",
            sourceLocator: "manual:domain",
            summary: "领域证据",
            excerpt: "领域证据",
            isProcessed: true
        )
        let removedNode = KnowledgeNode(name: "裸机中断", domain: "嵌入式裸机")
        let keptNode = KnowledgeNode(name: "进程调度", domain: "嵌入式 Linux")
        let removedState = MasteryState(knowledgeNodeID: removedNode.id, lifetimeXP: 90)
        let keptState = MasteryState(knowledgeNodeID: keptNode.id, lifetimeXP: 140)
        let evidence = makeEvidence(activityID: activity.id, nodeID: removedNode.id)
        let ledger = ScoreLedgerEntry(
            evidenceID: evidence.id,
            knowledgeNodeID: removedNode.id,
            timestamp: .now,
            previousComposite: 0,
            newComposite: 8,
            xpAwarded: 80,
            reason: "测试"
        )
        let edge = KnowledgeEdge(
            sourceNodeID: removedNode.id,
            targetNodeID: keptNode.id,
            relationRawValue: "相关",
            confidence: 0.9
        )
        let suggestion = TaxonomySuggestion(
            suggestionType: "reviewEvidence",
            proposedName: removedNode.name,
            relatedNodeID: removedNode.id,
            rationale: "测试",
            confidence: 0.7
        )
        let challenge = Challenge(
            title: "裸机挑战",
            challengeDescription: "测试",
            estimatedMinutes: 30,
            knowledgeNodeIDs: [removedNode.id],
            requirements: [],
            rewardXP: 0
        )
        insert(
            activity,
            removedNode,
            keptNode,
            removedState,
            keptState,
            evidence,
            ledger,
            edge,
            suggestion,
            challenge
        )

        try appState.deleteDomain("嵌入式裸机", strategy: .deleteKnowledge)

        XCTAssertNil(appState.node(for: removedNode.id))
        XCTAssertNotNil(appState.node(for: keptNode.id))
        XCTAssertNil(appState.mastery(for: removedNode.id))
        XCTAssertEqual(appState.mastery(for: keptNode.id)?.lifetimeXP, 140)
        XCTAssertTrue(appState.evidenceRecords.isEmpty)
        XCTAssertTrue(appState.scoreLedgerEntries.isEmpty)
        XCTAssertTrue(appState.knowledgeEdges.isEmpty)
        XCTAssertTrue(appState.taxonomySuggestions.isEmpty)
        XCTAssertTrue(appState.challenges.isEmpty)
        XCTAssertFalse(appState.activityEvents.contains { $0.id == activity.id })
        XCTAssertEqual(appState.pendingActivityCount, 0)
        XCTAssertEqual(appState.activityTrackingExclusions.count, 1)
        XCTAssertEqual(appState.activityTrackingExclusions.first?.sourceLocator, activity.sourceLocator)
    }

    private func makeEvidence(activityID: UUID = UUID(), nodeID: UUID) -> EvidenceRecord {
        EvidenceRecord(
            activityID: activityID,
            knowledgeNodeID: nodeID,
            kind: .project,
            timestamp: .now,
            summary: "真实证据",
            rationale: "测试依据",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.9,
            isVerified: true,
            fingerprint: UUID().uuidString
        )
    }

    private func insert(_ models: any PersistentModel...) {
        for model in models {
            container.mainContext.insert(model)
        }
        try? container.mainContext.save()
        appState.reload()
    }
}
