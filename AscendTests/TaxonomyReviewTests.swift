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

    func testNewKnowledgeUsesSuggestedDomainAndDoesNotAutoAwardXP() throws {
        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .markdownDirectory,
            timestamp: .now,
            fingerprint: "new-linux-note",
            title: "进程基础",
            sourceLocator: "/notes/进程基础.md",
            summary: "Markdown 更新",
            excerpt: "父进程与子进程"
        )
        let analyzed = AnalyzedEvidence(
            activityID: activity.id,
            knowledgeName: "父子进程关系",
            matchedNodeID: nil,
            matchConfidence: 0.99,
            kind: .explanation,
            difficulty: 1,
            independence: 1,
            confidence: 0.95,
            summary: "理解父进程与子进程的关系",
            rationale: "笔记解释了进程派生关系"
        )
        let nodeSuggestion = NodeSuggestion(
            proposedName: analyzed.knowledgeName,
            domain: "嵌入式 Linux",
            confidence: 0.95,
            rationale: analyzed.rationale
        )
        let envelope = AnalysisEnvelope(
            sessionSummary: "学习了嵌入式 Linux 的父子进程关系。",
            evidence: [analyzed],
            nodeSuggestions: [nodeSuggestion],
            edgeSuggestions: [],
            challengeSuggestion: nil
        )
        let run = AnalysisRun(endpointProfileID: nil, modelID: "mock", activityCount: 1)
        appState.modelContainer.mainContext.insert(activity)
        appState.modelContainer.mainContext.insert(run)

        let awardedXP = try appState.apply(envelope: envelope, to: [activity], analysisRun: run)
        try appState.modelContainer.mainContext.save()
        appState.reload()

        let node = try XCTUnwrap(appState.knowledgeNodes.first { $0.name == analyzed.knowledgeName })
        let evidence = try XCTUnwrap(appState.evidenceRecords.first { $0.activityID == activity.id })
        XCTAssertEqual(node.domain, "嵌入式 Linux")
        XCTAssertTrue(node.isProvisional)
        XCTAssertFalse(evidence.isVerified)
        XCTAssertEqual(awardedXP, 0)
        XCTAssertEqual(appState.mastery(for: node.id)?.lifetimeXP, 0)
        XCTAssertTrue(appState.taxonomySuggestions.contains { $0.suggestionType == "newNode" && $0.relatedNodeID == node.id })
        XCTAssertTrue(appState.taxonomySuggestions.contains { $0.suggestionType == "reviewEvidence" && $0.relatedNodeID == node.id })
    }

    func testClearAnalysisHistoryPreservesConfigurationAndRawActivities() throws {
        let endpoint = AIEndpointProfile(
            name: "本地接口",
            baseURLString: "https://mock.local/v1",
            selectedModelID: "mock"
        )
        let source = SourceConfiguration(
            name: "笔记",
            kind: .markdownDirectory,
            path: "/notes"
        )
        let activity = ActivityEvent(
            sourceID: source.id,
            sourceKind: .markdownDirectory,
            timestamp: .now,
            fingerprint: "clear-history-activity",
            title: "进程笔记",
            sourceLocator: "/notes/进程.md",
            summary: "笔记更新",
            excerpt: "父子进程",
            isProcessed: true
        )
        let node = KnowledgeNode(name: "父子进程", domain: "嵌入式 Linux")
        let evidence = EvidenceRecord(
            activityID: activity.id,
            knowledgeNodeID: node.id,
            kind: .explanation,
            timestamp: .now,
            summary: "理解父子进程",
            rationale: "笔记证据",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.9,
            isVerified: true,
            fingerprint: "clear-history-evidence"
        )
        let context = appState.modelContainer.mainContext
        context.insert(endpoint)
        context.insert(source)
        context.insert(activity)
        context.insert(node)
        context.insert(evidence)
        try context.save()
        appState.reload()

        try appState.clearAnalysisHistory()

        XCTAssertEqual(appState.endpointProfiles.map(\.id), [endpoint.id])
        XCTAssertEqual(appState.sources.map(\.id), [source.id])
        XCTAssertEqual(appState.activityEvents.map(\.id), [activity.id])
        XCTAssertFalse(try XCTUnwrap(appState.activityEvents.first).isProcessed)
        XCTAssertTrue(appState.knowledgeNodes.isEmpty)
        XCTAssertTrue(appState.evidenceRecords.isEmpty)
        XCTAssertTrue(appState.masteryStates.isEmpty)
        XCTAssertTrue(appState.scoreLedgerEntries.isEmpty)
    }

    func testReanalysisOverwritesSelectedActivityInsteadOfAppending() async throws {
        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .manual,
            timestamp: .now,
            fingerprint: "reanalyze-activity",
            title: "进程学习",
            sourceLocator: "manual:process",
            summary: "旧摘要",
            excerpt: "父子进程",
            isProcessed: true
        )
        let node = KnowledgeNode(name: "父子进程", domain: "嵌入式 Linux")
        let oldEvidence = EvidenceRecord(
            activityID: activity.id,
            knowledgeNodeID: node.id,
            kind: .exposure,
            timestamp: activity.timestamp,
            summary: "旧分析结果",
            rationale: "旧依据",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.9,
            isVerified: true,
            fingerprint: "reanalyze-old-evidence"
        )
        let state = MasteryState(knowledgeNodeID: node.id)
        let endpoint = AIEndpointProfile(
            name: "模拟接口",
            baseURLString: "https://mock.local/v1",
            selectedModelID: "mock"
        )
        let context = appState.modelContainer.mainContext
        context.insert(activity)
        context.insert(node)
        context.insert(oldEvidence)
        context.insert(state)
        context.insert(endpoint)
        try context.save()

        let analyzed = AnalyzedEvidence(
            activityID: activity.id,
            knowledgeName: node.name,
            matchedNodeID: node.id,
            matchConfidence: 0.99,
            kind: .independentSolve,
            difficulty: 1,
            independence: 1,
            confidence: 0.95,
            summary: "新的中文分析结果",
            rationale: "新的中文依据"
        )
        let client = ReanalysisStubClient(
            envelope: AnalysisEnvelope(
                sessionSummary: "重新分析完成。",
                evidence: [analyzed],
                nodeSuggestions: [],
                edgeSuggestions: [],
                challengeSuggestion: nil
            )
        )
        let reanalysisState = AppState(modelContainer: container, aiClient: client)
        reanalysisState.setActiveEndpoint(endpoint.id)

        await reanalysisState.reanalyze(activityIDs: [activity.id])

        XCTAssertEqual(reanalysisState.evidenceRecords.count { $0.activityID == activity.id }, 1)
        XCTAssertEqual(reanalysisState.evidenceRecords.first { $0.activityID == activity.id }?.summary, "新的中文分析结果")
        XCTAssertEqual(reanalysisState.scoreLedgerEntries.count { $0.knowledgeNodeID == node.id }, 1)
        XCTAssertTrue(activity.isProcessed)
        XCTAssertEqual(reanalysisState.statusMessage, "已重新分析并覆盖 1 条活动")
    }
}

private struct ReanalysisStubClient: AIProviderClient {
    let envelope: AnalysisEnvelope

    func listModels(endpoint: AIEndpointDescriptor, apiKey: String) async throws -> [RemoteModel] { [] }

    func test(endpoint: AIEndpointDescriptor, modelID: String, apiKey: String) async throws {}

    func analyze(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        activities: [CollectedActivity],
        candidateNodes: [KnowledgeCandidate],
        options: AnalysisOptions
    ) async throws -> AnalysisEnvelope {
        envelope
    }
}
