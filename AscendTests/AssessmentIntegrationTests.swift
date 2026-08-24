import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class AssessmentIntegrationTests: XCTestCase {
    func testDomainRoundUsesOneGenerationAndCoversFiveLeastMeasuredNodes() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<5).map { KnowledgeNode(name: "知识点 \($0)", domain: "Swift", isProvisional: false) }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let session = try await appState.startDomainAssessment(for: "Swift")
        let generationCount = await client.generationCount()
        XCTAssertEqual(generationCount, 1)
        try answerUntilComplete(appState: appState, session: session, correctly: true)

        XCTAssertEqual(appState.responses(for: session.id).count, 5)
        XCTAssertEqual(Set(appState.masteryObservations.map(\.knowledgeNodeID)), Set(nodes.map(\.id)))
        XCTAssertEqual(appState.evidenceRecords.filter { $0.assessmentSessionID == session.id }.count, 5)
    }

    func testEmbeddedAnalysisPackageIsReadyWithoutAssessmentGenerationCall() throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = [
            KnowledgeNode(name: "Actor", domain: "Swift", isProvisional: false),
            KnowledgeNode(name: "Sendable", domain: "Swift", isProvisional: false)
        ]
        let activity = ActivityEvent(
            sourceID: UUID(), sourceKind: .manual, timestamp: .now, fingerprint: "inline-package",
            title: "学习", sourceLocator: "manual", summary: "summary", excerpt: "excerpt", isProcessed: true
        )
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(activity)
        try container.mainContext.save()
        appState.reload()
        let tiers: [AssessmentTier] = [.foundational, .foundational, .application, .application, .application, .transfer, .transfer, .transfer]
        let embedded = EmbeddedAssessmentPackage(
            domain: "Swift",
            knowledgeNames: nodes.map(\.name),
            items: (0..<8).map { index in
                .init(
                    id: UUID(),
                    knowledgeName: nodes[index % nodes.count].name,
                    tier: tiers[index],
                    stem: "题目 \(index)",
                    answerOptions: ["A\(index)", "B\(index)", "C\(index)", "D\(index)"],
                    correctAnswerIndex: 0,
                    reasoningPrompt: "理由 \(index)",
                    reasoningOptions: ["R1-\(index)", "R2-\(index)", "R3-\(index)", "R4-\(index)"],
                    correctReasoningIndex: 0,
                    explanation: "解析 \(index)",
                    misconceptionTags: [],
                    sourceActivityIDs: [activity.id]
                )
            }
        )

        let session = try appState.persistEmbeddedAssessmentPackage(embedded, activities: [activity], generatorModelID: "analysis-model")

        XCTAssertEqual(session.generatorModelID, "analysis-model")
        XCTAssertEqual(appState.preparedDomainAssessment(for: "Swift")?.id, session.id)
        XCTAssertEqual(appState.items(for: session.id).count, 8)
    }

    func testRollingPreparationAutomaticallyCoversNodesOmittedFromFirstFive() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<8).map { KnowledgeNode(name: "队列知识点 \($0)", domain: "系统设计", isProvisional: false) }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let first = try await appState.startDomainAssessment(for: "系统设计")
        let initialRequests = await client.requests()
        let firstTargets = try XCTUnwrap(initialRequests.first).targetKnowledgeNodes.map(\.knowledgeNodeID)
        XCTAssertEqual(firstTargets.count, 5)
        try answerUntilComplete(appState: appState, session: first, correctly: true)

        for _ in 0..<100 where await client.generationCount() < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        let requests = await client.requests()
        XCTAssertEqual(requests.count, 2, "完成一轮后只应滚动补充一个题包")
        let secondTargets = Set(requests[1].targetKnowledgeNodes.map(\.knowledgeNodeID))
        let previouslyOmitted = Set(nodes.map(\.id)).subtracting(Set(firstTargets))
        XCTAssertTrue(previouslyOmitted.isSubset(of: secondTargets), "零观察知识点必须优先进入下一轮")
        XCTAssertEqual(secondTargets.count, 5, "每次调用应尽量合并五个目标")
        XCTAssertNotNil(appState.preparedDomainAssessment(for: "系统设计"))
    }

    func testAutomationPreparesOnlyOneRollingPackageWhileOneIsReady() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let container = PersistenceController.makeContainer(inMemory: true)
        let suiteName = "AssessmentIntegrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appState = AppState(modelContainer: container, aiClient: client, automationDefaults: defaults)
        let nodes = (0..<6).map { KnowledgeNode(name: "自动知识点 \($0)", domain: "自动领域", isProvisional: false) }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let now = Date(timeIntervalSince1970: 2_000_000_000)
        await appState.evaluateAutomaticAssessmentPreparation(now: now)
        await appState.evaluateAutomaticAssessmentPreparation(
            now: now.addingTimeInterval(AppConstants.automaticAssessmentRetryInterval + 1)
        )

        let generationCount = await client.generationCount()
        XCTAssertEqual(generationCount, 1)
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 5)
        XCTAssertEqual(appState.pendingVerificationKnowledgeCount, 6)
    }

    func testDisjointEmbeddedPackagesInSameDomainAreBothQueued() throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<4).map { KnowledgeNode(name: "并发知识点 \($0)", domain: "Swift", isProvisional: false) }
        let activity = ActivityEvent(
            sourceID: UUID(), sourceKind: .manual, timestamp: .now, fingerprint: "two-inline-packages",
            title: "学习", sourceLocator: "manual", summary: "summary", excerpt: "excerpt", isProcessed: true
        )
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(activity)
        try container.mainContext.save()
        appState.reload()

        let first = try appState.persistEmbeddedAssessmentPackage(
            makeEmbeddedPackage(nodes: Array(nodes[0...1]), activityID: activity.id),
            activities: [activity],
            generatorModelID: "analysis-model"
        )
        let second = try appState.persistEmbeddedAssessmentPackage(
            makeEmbeddedPackage(nodes: Array(nodes[2...3]), activityID: activity.id),
            activities: [activity],
            generatorModelID: "analysis-model"
        )

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(appState.assessmentSessions.count, 2)
        XCTAssertEqual(Set(appState.assessmentItems.map(\.knowledgeNodeID)), Set(nodes.map(\.id)))
    }

    func testOneGenerationRequestThenEntireSessionScoresLocally() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let (appState, node) = try makeAppState(client: client)

        let session = try await appState.startAssessment(for: node.id)
        let generationCountAfterStart = await client.generationCount()
        XCTAssertEqual(generationCountAfterStart, 1)
        try answerUntilComplete(appState: appState, session: session, correctly: true)

        let generationCountAfterSubmit = await client.generationCount()
        XCTAssertEqual(generationCountAfterSubmit, 1, "提交不得再次调用 AI")
        XCTAssertGreaterThanOrEqual(appState.masteryObservations.count, 6)
        XCTAssertGreaterThan(appState.totalXP, 0)
        XCTAssertEqual(appState.evidenceRecords.last?.verificationLevel, .directChoice)
        let exported = String(decoding: try appState.exportJSON(), as: UTF8.self)
        XCTAssertFalse(exported.contains("情境题"))
        XCTAssertFalse(exported.contains("固定反馈"))
        XCTAssertTrue(exported.contains("selectedAnswerIndex"))
        XCTAssertTrue(exported.contains("posteriorProbability"))
    }

    func testWrongResponsesLowerCurrentEstimateWithoutRemovingPeakXP() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let (appState, node) = try makeAppState(client: client)

        let first = try await appState.startAssessment(for: node.id)
        try answerUntilComplete(appState: appState, session: first, correctly: true)
        let high = try XCTUnwrap(appState.readiness(for: node.id)?.currentComposite)
        let earnedXP = appState.totalXP

        let second = try await appState.startAssessment(for: node.id)
        try answerUntilComplete(appState: appState, session: second, correctly: false)
        let lowered = try XCTUnwrap(appState.readiness(for: node.id)?.currentComposite)

        XCTAssertLessThan(lowered, high)
        XCTAssertEqual(appState.totalXP, earnedXP, "失败不倒扣 XP，也不重复奖励旧高点")
    }

    func testAssistedResponsesAreAuditedButDoNotCreateMasteryObservations() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let (appState, node) = try makeAppState(client: client)
        let session = try await appState.startAssessment(for: node.id)

        try answerUntilComplete(appState: appState, session: session, correctly: true, assisted: true)

        XCTAssertTrue(appState.masteryObservations.isEmpty)
        XCTAssertEqual(appState.totalXP, 0)
        XCTAssertEqual(appState.evidenceRecords.last?.assistanceMode, .aiAssisted)
    }

    func testInvalidPackageUsesOneRequestAndWritesNothing() async throws {
        let client = AssessmentStubClient(validItemCount: 4)
        let (appState, node) = try makeAppState(client: client)

        do {
            _ = try await appState.startAssessment(for: node.id)
            XCTFail("无效题包应抛错")
        } catch {}
        let generationCount = await client.generationCount()
        XCTAssertEqual(generationCount, 1)
        XCTAssertTrue(appState.assessmentSessions.isEmpty)
        XCTAssertTrue(appState.assessmentItems.isEmpty)
        XCTAssertTrue(appState.masteryObservations.isEmpty)
    }

    func testProductionReceiptsGateConnectedAndMasteredCertification() throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let (appState, node) = try makeAppState(client: client)
        for dimension in MasteryDimension.allCases {
            appState.modelContext.insert(
                MasteryEstimate(
                    knowledgeNodeID: node.id,
                    dimension: dimension,
                    probability: 0.95,
                    modelVersion: MasteryEstimator.modelVersion
                )
            )
        }
        try appState.modelContext.save()
        appState.reload()
        XCTAssertEqual(appState.readiness(for: node.id)?.certifiedStage, .integrated)

        let firstDate = Date(timeIntervalSince1970: 2_000_000_000)
        try appState.recordVerifiedPerformance(
            for: node.id,
            contextHash: "context-a",
            summary: "新情境实作 A",
            score: 0.9,
            scoringConfidence: 0.9,
            verificationLevel: .productionRubric,
            assistanceMode: .declaredUnassisted,
            occurredAt: firstDate
        )
        XCTAssertEqual(appState.readiness(for: node.id, now: firstDate)?.certifiedStage, .connected)

        try appState.recordVerifiedPerformance(
            for: node.id,
            contextHash: "context-b",
            summary: "新情境实作 B",
            score: 1,
            scoringConfidence: 1,
            verificationLevel: .productionDeterministic,
            assistanceMode: .declaredUnassisted,
            occurredAt: firstDate.addingTimeInterval(7 * 86_400)
        )
        XCTAssertEqual(
            appState.readiness(for: node.id, now: firstDate.addingTimeInterval(7 * 86_400))?.certifiedStage,
            .mastered
        )
    }

    func testLowConfidenceRubricProducesNoReceiptOrMasteryUpdate() throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let (appState, node) = try makeAppState(client: client)

        XCTAssertThrowsError(
            try appState.recordVerifiedPerformance(
                for: node.id,
                contextHash: "uncertain",
                summary: "低置信评分",
                score: 0.9,
                scoringConfidence: 0.4,
                verificationLevel: .productionRubric,
                assistanceMode: .declaredUnassisted
            )
        )
        XCTAssertTrue(appState.performanceReceipts.isEmpty)
        XCTAssertTrue(appState.masteryObservations.isEmpty)
        XCTAssertEqual(appState.totalXP, 0)
    }

    private func makeAppState(client: AssessmentStubClient) throws -> (AppState, KnowledgeNode) {
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let node = KnowledgeNode(name: "Swift actor", domain: "Swift", isProvisional: false)
        let endpoint = AIEndpointProfile(
            name: "Mock",
            baseURLString: "https://example.invalid/v1",
            selectedModelID: "mock-model"
        )
        container.mainContext.insert(node)
        container.mainContext.insert(MasteryState(knowledgeNodeID: node.id))
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)
        return (appState, node)
    }

    private func answerUntilComplete(
        appState: AppState,
        session: AssessmentSession,
        correctly: Bool,
        assisted: Bool = false
    ) throws {
        while session.statusRawValue == "active" {
            let item = try XCTUnwrap(appState.currentItem(for: session))
            _ = try appState.recordAssessmentResponse(
                session: session,
                item: item,
                selectedAnswerIndex: correctly ? item.correctAnswerIndex : (item.correctAnswerIndex + 1) % 4,
                selectedReasoningIndex: correctly ? item.correctReasoningIndex : (item.correctReasoningIndex + 1) % 4,
                usedAssistance: assisted
            )
        }
    }

    private func makeEmbeddedPackage(nodes: [KnowledgeNode], activityID: UUID) -> EmbeddedAssessmentPackage {
        EmbeddedAssessmentPackage(
            domain: nodes[0].domain,
            knowledgeNames: nodes.map(\.name),
            items: (0..<8).map { index in
                .init(
                    id: UUID(),
                    knowledgeName: nodes[index % nodes.count].name,
                    tier: AssessmentTier.allCases[index % AssessmentTier.allCases.count],
                    stem: "队列题目 \(nodes[0].name)-\(index)",
                    answerOptions: ["A\(index)", "B\(index)", "C\(index)", "D\(index)"],
                    correctAnswerIndex: 0,
                    reasoningPrompt: "队列理由 \(nodes[0].name)-\(index)",
                    reasoningOptions: ["R1-\(index)", "R2-\(index)", "R3-\(index)", "R4-\(index)"],
                    correctReasoningIndex: 0,
                    explanation: "解析 \(index)",
                    misconceptionTags: [],
                    sourceActivityIDs: [activityID]
                )
            }
        )
    }
}

private actor AssessmentStubClient: AIProviderClient {
    private let validItemCount: Int
    private var calls = 0
    private var capturedRequests: [AssessmentRequest] = []

    init(validItemCount: Int) {
        self.validItemCount = validItemCount
    }

    func generationCount() -> Int { calls }
    func requests() -> [AssessmentRequest] { capturedRequests }

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
        AnalysisEnvelope(sessionSummary: "", evidence: [], nodeSuggestions: [], edgeSuggestions: [], challengeSuggestion: nil)
    }

    func generateAssessment(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        request: AssessmentRequest
    ) async throws -> AssessmentPackage {
        calls += 1
        capturedRequests.append(request)
        let tiers: [AssessmentTier] = [.foundational, .foundational, .application, .application, .application, .transfer, .transfer, .transfer]
        let items = (0..<validItemCount).map { index in
            AssessmentPackage.Item(
                knowledgeNodeID: request.targetKnowledgeNodes[index % request.targetKnowledgeNodes.count].knowledgeNodeID,
                tier: tiers[index % tiers.count],
                stem: "情境题 \(calls)-\(index)",
                answerOptions: ["A\(index)", "B\(index)", "C\(index)", "D\(index)"],
                correctAnswerIndex: 0,
                reasoningPrompt: "选择理由 \(calls)-\(index)",
                reasoningOptions: ["R1-\(index)", "R2-\(index)", "R3-\(index)", "R4-\(index)"],
                correctReasoningIndex: 0,
                explanation: "固定反馈 \(index)",
                misconceptionTags: ["误区 \(index)"],
                sourceActivityIDs: []
            )
        }
        return AssessmentPackage(knowledgeNodeID: request.knowledgeNodeID, items: items)
    }
}
