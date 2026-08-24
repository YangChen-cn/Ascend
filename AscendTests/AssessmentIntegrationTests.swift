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
        let tiers: [AssessmentTier] = [.foundational, .application, .transfer, .application, .transfer, .foundational]
        let embedded = EmbeddedAssessmentPackage(
            domain: "Swift",
            knowledgeNames: nodes.map(\.name),
            items: (0..<6).map { index in
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
        XCTAssertEqual(appState.items(for: session.id).count, 6)
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
        let generationCount = await client.generationCount()
        let batchSizes = await client.batchSizes()
        XCTAssertEqual(generationCount, 2, "完成一轮后应以一次批量请求补齐剩余队列")
        let batchTargets = Set(requests.dropFirst().flatMap { $0.targetKnowledgeNodes.map(\.knowledgeNodeID) })
        let previouslyOmitted = Set(nodes.map(\.id)).subtracting(Set(firstTargets))
        XCTAssertTrue(previouslyOmitted.isSubset(of: batchTargets), "零观察知识点必须进入下一次批量请求")
        XCTAssertEqual(batchSizes, [8])
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
        appState.automaticAssessmentPreparationEnabled = true
        await appState.evaluateAutomaticAssessmentPreparation(now: now)
        await appState.evaluateAutomaticAssessmentPreparation(
            now: now.addingTimeInterval(AppConstants.automaticAssessmentRetryInterval + 1)
        )

        let generationCount = await client.generationCount()
        XCTAssertEqual(generationCount, 1)
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 6)
        XCTAssertEqual(appState.pendingVerificationKnowledgeCount, 6)
    }

    func testAutomationDoesNotPrepareWhenDisabledByDefault() async throws {
        let client = AssessmentStubClient(validItemCount: 6)
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

        XCTAssertFalse(appState.automaticAssessmentPreparationEnabled)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        await appState.evaluateAutomaticAssessmentPreparation(now: now)

        let generationCount = await client.generationCount()
        XCTAssertEqual(generationCount, 0, "默认关闭时不应触发 AI 题包生成")
    }

    func testThirtyThreeNodesUseFourBoundedAICallsAndPrepareEveryNode() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<33).map {
            KnowledgeNode(name: "批量知识点 \($0)", domain: $0 < 18 ? "嵌入式" : "Swift", isProvisional: false)
        }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let first = await appState.prepareAllPendingAssessments()
        let generationCount = await client.generationCount()
        let batchSizes = await client.batchSizes()

        XCTAssertNotNil(first)
        XCTAssertEqual(generationCount, 4)
        XCTAssertEqual(batchSizes.reduce(0, +), 33)
        XCTAssertTrue(batchSizes.allSatisfy { $0 <= AppConstants.maximumAssessmentTargetsPerRequest })
        XCTAssertEqual(appState.assessmentSessions.count, 7)
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 33)
        XCTAssertEqual(Set(appState.assessmentItems.map(\.knowledgeNodeID)), Set(nodes.map(\.id)))
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("33 个知识点") == true)
    }

    func testBatchFailureKeepsCompletedBatchesAndReportsRemainingWork() async throws {
        let client = AssessmentStubClient(validItemCount: 8, failingBatchCall: 2)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<12).map {
            KnowledgeNode(name: "续备知识点 \($0)", domain: "系统设计", isProvisional: false)
        }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let session = await appState.prepareAllPendingAssessments()
        let generationCount = await client.generationCount()

        XCTAssertNil(session, "部分失败时不应假装整批成功并直接打开答题")
        XCTAssertEqual(generationCount, 2)
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 10)
        XCTAssertEqual(appState.pendingVerificationKnowledgeCount, 12)
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("已准备 10/12") == true)
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("模拟批量失败") == true)
    }

    func testIncompatibleBatchFallsBackOnceAndCachesSinglePackageMode() async throws {
        let client = AssessmentStubClient(validItemCount: 8, incompatibleBatchCall: 1)
        let container = PersistenceController.makeContainer(inMemory: true)
        let suiteName = "AssessmentIntegrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appState = AppState(modelContainer: container, aiClient: client, automationDefaults: defaults)
        let nodes = (0..<12).map {
            KnowledgeNode(name: "兼容知识点 \($0)", domain: "系统设计", isProvisional: false)
        }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let first = await appState.prepareAllPendingAssessments()
        let firstBatchCalls = await client.batchGenerationCount()
        let firstSingleCalls = await client.singleGenerationCount()

        XCTAssertNotNil(first)
        XCTAssertEqual(firstBatchCalls, 1, "批量格式首次不兼容后，本轮不得继续重复尝试批量格式")
        XCTAssertEqual(firstSingleCalls, 3)
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 12)
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("兼容模式") == true)

        let newNode = KnowledgeNode(name: "后续兼容知识点", domain: "系统设计", isProvisional: false)
        container.mainContext.insert(newNode)
        try container.mainContext.save()
        appState.reload()

        let second = await appState.prepareAllPendingAssessments()
        let secondBatchCalls = await client.batchGenerationCount()
        let secondSingleCalls = await client.singleGenerationCount()

        XCTAssertNotNil(second)
        XCTAssertEqual(secondBatchCalls, 1, "同一 Endpoint 与模型应复用兼容模式，避免再次浪费失败调用")
        XCTAssertEqual(secondSingleCalls, 4)
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 13)
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

    func testAssessmentRequestCapsSourceCountAndTextLengths() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let (appState, node) = try makeAppState(client: client)
        for index in 0..<8 {
            let activity = ActivityEvent(
                sourceID: UUID(),
                sourceKind: .manual,
                timestamp: Date().addingTimeInterval(Double(index)),
                fingerprint: "bounded-source-\(index)",
                title: String(repeating: "题", count: 300),
                sourceLocator: "manual",
                summary: String(repeating: "摘要", count: 400),
                excerpt: String(repeating: "审计片段", count: 500),
                isProcessed: true
            )
            let evidence = EvidenceRecord(
                activityID: activity.id,
                knowledgeNodeID: node.id,
                kind: .exposure,
                timestamp: activity.timestamp,
                summary: "产物线索",
                rationale: "仅用于生成测量题",
                difficulty: 0,
                independence: 0,
                aiConfidence: 1,
                isVerified: false,
                fingerprint: "bounded-evidence-\(index)",
                origin: .artifact
            )
            appState.modelContext.insert(activity)
            appState.modelContext.insert(evidence)
        }
        try appState.modelContext.save()
        appState.reload()

        _ = try await appState.startAssessment(for: node.id)
        let requests = await client.requests()
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(request.sourceMaterials.count, AppConstants.maximumAssessmentSourceMaterialsPerPackage)
        XCTAssertTrue(request.sourceMaterials.allSatisfy {
            $0.title.count <= AppConstants.maximumAssessmentSourceTitleLength
                && $0.summary.count <= AppConstants.maximumAssessmentSourceSummaryLength
                && $0.excerpt.count <= AppConstants.maximumAssessmentSourceExcerptLength
        })
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

    func testStartAssessmentReusesActiveDomainComprehensiveSession() async throws {
        let client = AssessmentStubClient(validItemCount: 6)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<3).map { KnowledgeNode(name: "并发知识点 \($0)", domain: "Swift", isProvisional: false) }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let domainSession = try await appState.startDomainAssessment(for: "Swift")
        let genCount1 = await client.generationCount()
        XCTAssertEqual(genCount1, 1)

        let singleNodeSession = try await appState.startAssessment(for: nodes[1].id)
        XCTAssertEqual(singleNodeSession.id, domainSession.id, "知识点已包含在活跃综合题包中时应直接复用，不重复调用 AI")
        let genCount2 = await client.generationCount()
        XCTAssertEqual(genCount2, 1)
    }

    func testMeasurementStatusCalibratedOnlyCountsNodeScopedDistinctResponses() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container)
        let targetNode = KnowledgeNode(name: "目标知识点", domain: "Swift", isProvisional: false)
        let otherNode = KnowledgeNode(name: "其他知识点", domain: "Swift", isProvisional: false)
        container.mainContext.insert(targetNode)
        container.mainContext.insert(otherNode)
        container.mainContext.insert(MasteryState(knowledgeNodeID: targetNode.id))
        container.mainContext.insert(MasteryState(knowledgeNodeID: otherNode.id))

        // Create 30 observations for otherNode
        for i in 0..<30 {
            let obs = MasteryObservation(
                canonicalKey: "other-\(i)",
                sessionID: UUID(),
                itemID: UUID(),
                responseID: UUID(),
                knowledgeNodeID: otherNode.id,
                dimension: .understanding,
                isCorrect: i % 2 == 0,
                guessProbability: 0.25,
                slipProbability: 0.1,
                priorProbability: 0.5,
                predictedCorrectProbability: 0.5,
                posteriorProbability: 0.5,
                observedAt: .now,
                modelVersion: 1
            )
            container.mainContext.insert(obs)
        }
        try container.mainContext.save()
        appState.reload()

        // targetNode should NOT be calibrated just because global observations >= 30
        let targetStatusBefore = appState.readiness(for: targetNode.id)?.measurementStatus
        XCTAssertNotEqual(targetStatusBefore, .calibrated)

        // Now add 5 distinct correct responses and 5 distinct incorrect responses specifically for targetNode
        for i in 0..<5 {
            let responseID = UUID()
            let obs1 = MasteryObservation(
                canonicalKey: "target-c1-\(i)",
                sessionID: UUID(),
                itemID: UUID(),
                responseID: responseID,
                knowledgeNodeID: targetNode.id,
                dimension: .exposure,
                isCorrect: true,
                guessProbability: 0.25,
                slipProbability: 0.1,
                priorProbability: 0.5,
                predictedCorrectProbability: 0.5,
                posteriorProbability: 0.5,
                observedAt: .now,
                modelVersion: 1
            )
            let obs2 = MasteryObservation(
                canonicalKey: "target-c2-\(i)",
                sessionID: UUID(),
                itemID: UUID(),
                responseID: responseID,
                knowledgeNodeID: targetNode.id,
                dimension: .understanding,
                isCorrect: true,
                guessProbability: 0.25,
                slipProbability: 0.1,
                priorProbability: 0.5,
                predictedCorrectProbability: 0.5,
                posteriorProbability: 0.5,
                observedAt: .now,
                modelVersion: 1
            )
            container.mainContext.insert(obs1)
            container.mainContext.insert(obs2)
        }
        for i in 0..<5 {
            let responseID = UUID()
            let obs = MasteryObservation(
                canonicalKey: "target-inc-\(i)",
                sessionID: UUID(),
                itemID: UUID(),
                responseID: responseID,
                knowledgeNodeID: targetNode.id,
                dimension: .understanding,
                isCorrect: false,
                guessProbability: 0.25,
                slipProbability: 0.1,
                priorProbability: 0.5,
                predictedCorrectProbability: 0.5,
                posteriorProbability: 0.5,
                observedAt: .now,
                modelVersion: 1
            )
            container.mainContext.insert(obs)
        }
        try container.mainContext.save()
        appState.reload()

        let targetStatusAfter = appState.readiness(for: targetNode.id)?.measurementStatus
        XCTAssertEqual(targetStatusAfter, .calibrated, "目标知识点自身具备 5 对 5 错的独立样本时才标记为 calibrated")
    }

    func testProductionPerformanceTierGrading() throws {
        let client = AssessmentStubClient(validItemCount: 6)
        let (appState, node) = try makeAppState(client: client)

        // score 0.79 should be a weak pass (isPassing = true), not a hard failure
        let gradeWeak = ProductionPerformanceGrade.grade(for: 0.79)
        XCTAssertEqual(gradeWeak, .weak)
        XCTAssertTrue(gradeWeak.isPassing)

        try appState.recordVerifiedPerformance(
            for: node.id,
            contextHash: "context-weak",
            summary: "弱通过表现",
            score: 0.79,
            scoringConfidence: 0.9,
            verificationLevel: .productionDeterministic,
            assistanceMode: .declaredUnassisted
        )

        let obs = try XCTUnwrap(appState.observationsByNodeID[node.id]?.first)
        XCTAssertTrue(obs.isCorrect, "0.79 应当作为弱通过计入")
        XCTAssertEqual(obs.guessProbability, 0.05)
        XCTAssertEqual(obs.slipProbability, 0.20)
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
            items: (0..<6).map { index in
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
    private let failingBatchCall: Int?
    private let incompatibleBatchCall: Int?
    private var calls = 0
    private var singleCalls = 0
    private var batchCalls = 0
    private var capturedRequests: [AssessmentRequest] = []
    private var capturedBatchSizes: [Int] = []

    init(
        validItemCount: Int,
        failingBatchCall: Int? = nil,
        incompatibleBatchCall: Int? = nil
    ) {
        self.validItemCount = validItemCount
        self.failingBatchCall = failingBatchCall
        self.incompatibleBatchCall = incompatibleBatchCall
    }

    func generationCount() -> Int { calls }
    func singleGenerationCount() -> Int { singleCalls }
    func batchGenerationCount() -> Int { batchCalls }
    func requests() -> [AssessmentRequest] { capturedRequests }
    func batchSizes() -> [Int] { capturedBatchSizes }

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
        singleCalls += 1
        capturedRequests.append(request)
        return makePackage(request: request, itemCount: validItemCount, call: calls)
    }

    func generateAssessmentBatch(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        requests: [AssessmentRequest]
    ) async throws -> [AssessmentPackage] {
        calls += 1
        batchCalls += 1
        if calls == incompatibleBatchCall {
            throw AssessmentGenerationError.batchFormatIncompatible("缺少字段 packages[0].items")
        }
        if calls == failingBatchCall {
            throw AssessmentStubError.batchFailure
        }
        capturedRequests.append(contentsOf: requests)
        capturedBatchSizes.append(requests.reduce(0) { $0 + $1.targetKnowledgeNodes.count })
        return requests.map { makePackage(request: $0, itemCount: 5, call: calls) }
    }

    private func makePackage(
        request: AssessmentRequest,
        itemCount: Int,
        call: Int
    ) -> AssessmentPackage {
        let tiers: [AssessmentTier] = [.foundational, .application, .transfer, .application, .transfer, .foundational, .application, .transfer]
        let items = (0..<itemCount).map { index in
            AssessmentPackage.Item(
                knowledgeNodeID: request.targetKnowledgeNodes[index % request.targetKnowledgeNodes.count].knowledgeNodeID,
                tier: tiers[index % tiers.count],
                stem: "情境题 \(call)-\(index)",
                answerOptions: ["A\(index)", "B\(index)", "C\(index)", "D\(index)"],
                correctAnswerIndex: 0,
                reasoningPrompt: "选择理由 \(call)-\(index)",
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

private enum AssessmentStubError: LocalizedError {
    case batchFailure

    var errorDescription: String? { "模拟批量失败" }
}
