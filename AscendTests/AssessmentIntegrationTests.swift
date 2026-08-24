import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class AssessmentIntegrationTests: XCTestCase {
    func testBalancedBatchPlannerAppliesToEveryPackageCount() {
        let maximumPackagesPerRequest = AppConstants.maximumAssessmentTargetsPerRequest
            / AppConstants.maximumAssessmentTargetsPerPackage

        for totalPackages in 1...100 {
            let counts = AssessmentBatchPlanner.balancedPackageCounts(
                totalPackages: totalPackages,
                maximumPackagesPerRequest: maximumPackagesPerRequest
            )
            let expectedRequestCount = Int(
                ceil(Double(totalPackages) / Double(maximumPackagesPerRequest))
            )

            XCTAssertEqual(counts.reduce(0, +), totalPackages)
            XCTAssertEqual(counts.count, expectedRequestCount)
            XCTAssertLessThanOrEqual(counts.max() ?? 0, maximumPackagesPerRequest)
            XCTAssertLessThanOrEqual((counts.max() ?? 0) - (counts.min() ?? 0), 1)
            XCTAssertEqual(counts, counts.sorted(), "较大的批次应放在后面，避免很小的尾批")
        }
    }

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
        XCTAssertEqual(batchSizes, [3], "刚完成的 5 个知识点进入冷却，只补齐此前未覆盖的 3 个")
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

    func testThirtyThreeNodesUseThreeBoundedAICallsAndPrepareEveryNode() async throws {
        let client = AssessmentStubClient(validItemCount: 6)
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
        XCTAssertEqual(generationCount, 3, "33 个知识点在最多 3 包/请求下应产生 3 次 API 调用")
        XCTAssertEqual(batchSizes, [10, 10, 13], "33 个知识点应均衡拆分，避免最后只剩 3 个")
        XCTAssertEqual(batchSizes.reduce(0, +), 33)
        XCTAssertTrue(batchSizes.allSatisfy { $0 <= AppConstants.maximumAssessmentTargetsPerRequest })
        XCTAssertEqual(appState.assessmentSessions.count, 7)
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 33)
        XCTAssertEqual(Set(appState.assessmentItems.map(\.knowledgeNodeID)), Set(nodes.map(\.id)))
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("33 个知识点") == true)
    }

    func testCompletingOneFullyPreparedBatchDoesNotRegenerateTheSameNodes() async throws {
        let client = AssessmentStubClient(validItemCount: 5)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<33).map {
            KnowledgeNode(name: "轮次知识点 \($0)", domain: "Swift", isProvisional: false)
        }
        let endpoint = AIEndpointProfile(
            name: "Mock",
            baseURLString: "https://example.invalid/v1",
            selectedModelID: "mock-model"
        )
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let preparedSession = await appState.prepareAllPendingAssessments()
        let firstSession = try XCTUnwrap(preparedSession)
        let initialGenerationCount = await client.generationCount()
        XCTAssertEqual(initialGenerationCount, 3)
        let measuredNodeIDs = Set(appState.items(for: firstSession.id).map(\.knowledgeNodeID))

        try answerUntilComplete(appState: appState, session: firstSession, correctly: true)
        try await Task.sleep(for: .milliseconds(100))

        let finalGenerationCount = await client.generationCount()
        XCTAssertEqual(finalGenerationCount, 3, "仍有 28 个现成知识点题包时不得再次调用 AI")
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 28)
        XCTAssertEqual(appState.pendingVerificationKnowledgeCount, 28)
        let activeNodeIDs = Set(appState.assessmentSessions
            .filter { $0.statusRawValue == "active" }
            .flatMap { appState.items(for: $0.id).map(\.knowledgeNodeID) })
        XCTAssertTrue(measuredNodeIDs.isDisjoint(with: activeNodeIDs), "刚答完的知识点不得在同一轮重新入队")
    }

    func testBaselinePerformanceCreatesInitialDelayedReviewPlan() async throws {
        let client = AssessmentStubClient(validItemCount: 5)
        let (appState, node) = try makeAppState(client: client)
        let session = try await appState.startAssessment(for: node.id)
        let item = try XCTUnwrap(appState.currentItem(for: session))

        _ = try appState.recordAssessmentResponse(
            session: session,
            item: item,
            selectedAnswerIndex: item.correctAnswerIndex,
            selectedReasoningIndex: item.correctReasoningIndex,
            usedAssistance: false
        )

        let plan = try XCTUnwrap(appState.reviewPlans.first(where: { $0.knowledgeNodeID == node.id }))
        XCTAssertEqual(plan.status, "scheduled")
        XCTAssertEqual(
            plan.scheduledAt.timeIntervalSince(appState.responses(for: session.id)[0].answeredAt),
            AppConstants.initialReviewDelay,
            accuracy: 1
        )
    }

    func testDueReviewStartsDelayedReviewInsteadOfPreparedBaselineSession() async throws {
        let client = AssessmentStubClient(validItemCount: 5)
        let (appState, node) = try makeAppState(client: client)
        let baseline = try await appState.startAssessment(for: node.id)
        try appState.scheduleReview(
            for: node.id,
            scheduledAt: .now.addingTimeInterval(-60),
            reason: "测试到期复习"
        )
        let plan = try XCTUnwrap(appState.reviewPlans.first(where: { $0.knowledgeNodeID == node.id }))
        XCTAssertEqual(plan.status, "due")

        let review = try await appState.startAssessment(for: node.id)

        XCTAssertNotEqual(review.id, baseline.id)
        XCTAssertEqual(review.kind, .delayedReview)
        XCTAssertEqual(review.reviewPlanID, plan.id)
        let generationCount = await client.generationCount()
        XCTAssertEqual(generationCount, 2)
    }

    func testReloadSupersedesUnansweredPackageThatDuplicatesRecentlyMeasuredNode() async throws {
        let client = AssessmentStubClient(validItemCount: 5)
        let (appState, node) = try makeAppState(client: client)
        let redundantSession = try await appState.startAssessment(for: node.id)
        let measuredAt = Date.now
        appState.modelContext.insert(
            MasteryEstimate(
                knowledgeNodeID: node.id,
                dimension: .exposure,
                probability: 0.5,
                observationCount: 1,
                correctCount: 1,
                lastObservedAt: measuredAt,
                modelVersion: MasteryEstimator.modelVersion
            )
        )
        try appState.modelContext.save()

        appState.reload()

        XCTAssertEqual(redundantSession.statusRawValue, "superseded")
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 0)
        XCTAssertEqual(appState.pendingVerificationKnowledgeCount, 0)
    }

    func testSkippedNodeDoesNotImmediatelyRegenerateInTheSameAssessmentRound() async throws {
        let client = AssessmentStubClient(validItemCount: 5)
        let (appState, node) = try makeAppState(client: client)
        let firstSession = try await appState.startAssessment(for: node.id)
        let item = try XCTUnwrap(appState.currentItem(for: firstSession))

        _ = try appState.skipAssessmentItem(session: firstSession, item: item)
        while firstSession.statusRawValue == "active" {
            let nextItem = try XCTUnwrap(appState.currentItem(for: firstSession))
            _ = try appState.skipAssessmentItem(session: firstSession, item: nextItem)
        }

        XCTAssertEqual(appState.pendingVerificationKnowledgeCount, 0)
        let preparedAgain = await appState.prepareNextDomainAssessmentIfNeeded()
        XCTAssertNil(preparedAgain)
        let generationCount = await client.generationCount()
        XCTAssertEqual(generationCount, 1, "跳过属于本轮已尝试，不应立即再次消耗 AI 备同一知识点")
    }

    func testBatchFailureKeepsCompletedBatchesAndReportsRemainingWork() async throws {
        let client = AssessmentStubClient(validItemCount: 6, failingBatchCall: 2)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<25).map {
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
        XCTAssertEqual(appState.pendingVerificationKnowledgeCount, 25)
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("已准备 10/25") == true)
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("模拟批量失败") == true)
    }

    func testIncompatibleBatchReducesLimitAndCachesAdaptiveMode() async throws {
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
        XCTAssertEqual(firstBatchCalls, 3, "首次格式不兼容后应从 15 个降到 10 个并完成剩余题包")
        XCTAssertEqual(firstSingleCalls, 0)
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 12)
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("动态批次上限为 10") == true)

        let newNode = KnowledgeNode(name: "后续兼容知识点", domain: "系统设计", isProvisional: false)
        container.mainContext.insert(newNode)
        try container.mainContext.save()
        appState.reload()

        let second = await appState.prepareAllPendingAssessments()
        let secondBatchCalls = await client.batchGenerationCount()
        let secondSingleCalls = await client.singleGenerationCount()

        XCTAssertNotNil(second)
        XCTAssertEqual(secondBatchCalls, 4, "同一 Endpoint 与模型应复用 10 个知识点的安全上限")
        XCTAssertEqual(secondSingleCalls, 0)
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 13)
    }

    func testSuccessfulFullBatchesImmediatelyPromoteCachedLimitFromFiveToTenToFifteen() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let container = PersistenceController.makeContainer(inMemory: true)
        let suiteName = "AssessmentIntegrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let endpoint = AIEndpointProfile(
            name: "Mock",
            baseURLString: "https://example.invalid/v1",
            selectedModelID: "mock-model"
        )
        let compatibilityKey = "\(endpoint.id.uuidString)|\(endpoint.selectedModelID)"
        defaults.set(
            [compatibilityKey: "1|\(Date().timeIntervalSince1970)"],
            forKey: AppConstants.assessmentBatchLimitCompatibilityKey
        )
        let appState = AppState(modelContainer: container, aiClient: client, automationDefaults: defaults)
        let initialNodes = (0..<15).map {
            KnowledgeNode(name: "升档知识点 \($0)", domain: "网络诊断", isProvisional: false)
        }
        initialNodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let firstSession = await appState.prepareAllPendingAssessments()
        let firstAttemptedBatchSizes = await client.attemptedBatchSizes()
        XCTAssertNotNil(firstSession)
        XCTAssertEqual(firstAttemptedBatchSizes, [5, 10])
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("动态批次上限为 15") == true)

        let laterNodes = (15..<30).map {
            KnowledgeNode(name: "升档知识点 \($0)", domain: "网络诊断", isProvisional: false)
        }
        laterNodes.forEach(container.mainContext.insert)
        try container.mainContext.save()
        appState.reload()

        let secondSession = await appState.prepareAllPendingAssessments()
        let secondAttemptedBatchSizes = await client.attemptedBatchSizes()
        XCTAssertNotNil(secondSession)
        XCTAssertEqual(secondAttemptedBatchSizes, [5, 10, 15])
    }

    func testInterruptedBatchFallsBackThenPromotesAgainAfterSuccessfulFullBatches() async throws {
        let client = AssessmentStubClient(validItemCount: 8, interruptedBatchCalls: [1, 2])
        let container = PersistenceController.makeContainer(inMemory: true)
        let suiteName = "AssessmentIntegrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appState = AppState(modelContainer: container, aiClient: client, automationDefaults: defaults)
        let nodes = (0..<26).map {
            KnowledgeNode(name: "断线知识点 \($0)", domain: "网络诊断", isProvisional: false)
        }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let session = await appState.prepareAllPendingAssessments()
        let batchCalls = await client.batchGenerationCount()
        let singleCalls = await client.singleGenerationCount()
        let attemptedBatchSizes = await client.attemptedBatchSizes()

        XCTAssertNotNil(session)
        XCTAssertEqual(batchCalls, 6)
        XCTAssertEqual(singleCalls, 0)
        XCTAssertEqual(attemptedBatchSizes, [15, 10, 5, 5, 10, 6])
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 26)
        XCTAssertTrue(appState.assessmentPreparationMessage?.localizedStandardContains("动态批次上限为 15") == true)
    }

    func testMinimumBatchTransportInterruptionRetriesOnceWithFreshRequest() async throws {
        let client = AssessmentStubClient(validItemCount: 8, interruptedBatchCalls: [1])
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<5).map {
            KnowledgeNode(name: "最小批次知识点 \($0)", domain: "网络诊断", isProvisional: false)
        }
        let endpoint = AIEndpointProfile(
            name: "Mock",
            baseURLString: "https://example.invalid/v1",
            selectedModelID: "mock-model"
        )
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        let session = await appState.prepareAllPendingAssessments()
        let batchGenerationCount = await client.batchGenerationCount()
        let attemptedBatchSizes = await client.attemptedBatchSizes()

        XCTAssertNotNil(session)
        XCTAssertEqual(batchGenerationCount, 2)
        XCTAssertEqual(attemptedBatchSizes, [5, 5])
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 5)
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
        XCTAssertGreaterThanOrEqual(appState.masteryObservations.count, 2)
        XCTAssertGreaterThan(appState.totalXP, 0)
        XCTAssertEqual(appState.evidenceRecords.last?.verificationLevel, .directChoice)
        let exported = String(decoding: try appState.exportJSON(), as: UTF8.self)
        XCTAssertFalse(exported.contains("情境题"))
        XCTAssertFalse(exported.contains("固定反馈"))
        XCTAssertTrue(exported.contains("selectedAnswerIndex"))
        XCTAssertTrue(exported.contains("posteriorProbability"))
    }

    func testSessionFinalizationSettlesMasteryEvidenceAndXP() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let (appState, node) = try makeAppState(client: client)
        let session = try await appState.startAssessment(for: node.id)
        let item = try XCTUnwrap(appState.currentItem(for: session))

        let progress = try appState.recordAssessmentResponse(
            session: session,
            item: item,
            selectedAnswerIndex: item.correctAnswerIndex,
            selectedReasoningIndex: item.correctReasoningIndex,
            usedAssistance: false
        )

        // 首题表现明确，直接完成 session
        XCTAssertTrue(progress.isCompleted)
        XCTAssertEqual(session.statusRawValue, "completed")
        XCTAssertEqual(appState.masteryObservations.count, 2)
        XCTAssertEqual(appState.evidenceRecords.count(where: { $0.assessmentSessionID == session.id }), 1)
        XCTAssertEqual(appState.scoreLedgerEntries.count(where: { $0.knowledgeNodeID == node.id }), 1)
        XCTAssertGreaterThan(appState.totalXP, 0, "session 达到有效条件完成后正式结算 XP")
    }

    func testSkippingProducesNoMasteryObservationAndAdvancesWithoutXP() async throws {
        let client = AssessmentStubClient(validItemCount: 8)
        let (appState, node) = try makeAppState(client: client)
        let session = try await appState.startAssessment(for: node.id)
        let item = try XCTUnwrap(appState.currentItem(for: session))

        let progress = try appState.skipAssessmentItem(session: session, item: item)
        let response = try XCTUnwrap(appState.responses(for: session.id).first)

        XCTAssertTrue(response.wasSkipped)
        XCTAssertEqual(response.selectedAnswerIndex, -1)
        XCTAssertEqual(response.selectedReasoningIndex, -1)
        XCTAssertTrue(appState.masteryObservations.isEmpty, "跳过不得产生 mastery observation")
        XCTAssertEqual(appState.totalXP, 0)
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

    func testBatchAssessmentCallCountsFor33Nodes() async throws {
        let client = AssessmentStubClient(validItemCount: 5)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<33).map { KnowledgeNode(name: "知识点 \($0)", domain: "Swift", isProvisional: false) }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        _ = await appState.prepareAllPendingAssessments()
        let genCount = await client.generationCount()
        XCTAssertEqual(genCount, 3, "33 个知识点（7 个题包）在最多 3 包/请求下应产生 3 次 API 调用")
    }

    func testBatchAssessmentCallCountsFor40Nodes() async throws {
        let client = AssessmentStubClient(validItemCount: 5)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<40).map { KnowledgeNode(name: "知识点 \($0)", domain: "Swift", isProvisional: false) }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        _ = await appState.prepareAllPendingAssessments()
        let genCount = await client.generationCount()
        XCTAssertEqual(genCount, 3, "40 个知识点（8 个题包）在最多 3 包/请求下应产生 3 次 API 调用")
    }

    func testBatchAssessmentCallCountsFor41Nodes() async throws {
        let client = AssessmentStubClient(validItemCount: 5)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: client)
        let nodes = (0..<41).map { KnowledgeNode(name: "知识点 \($0)", domain: "Swift", isProvisional: false) }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        _ = await appState.prepareAllPendingAssessments()
        let genCount = await client.generationCount()
        XCTAssertEqual(genCount, 3, "41 个知识点（9 个题包）在最多 3 包/请求下应产生 3 次 API 调用")
    }

    func testPartialBatchFailureRetainsSucceededSessionsAndOnlyRetriesUncompletedNodes() async throws {
        // 33 nodes = 3 balanced batches (2 packages/10 nodes, 2 packages/10 nodes, 3 packages/13 nodes)
        // Set failingBatchCall = 2 (fails on Batch 2)
        let failingClient = AssessmentStubClient(validItemCount: 5, failingBatchCall: 2)
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container, aiClient: failingClient)
        let nodes = (0..<33).map { KnowledgeNode(name: "知识点 \($0)", domain: "Swift", isProvisional: false) }
        let endpoint = AIEndpointProfile(name: "Mock", baseURLString: "https://example.invalid/v1", selectedModelID: "mock-model")
        nodes.forEach(container.mainContext.insert)
        container.mainContext.insert(endpoint)
        try container.mainContext.save()
        appState.reload()
        appState.setActiveEndpoint(endpoint.id)

        // First attempt: batch 1 succeeds (10 nodes persisted), batch 2 fails
        let result1 = await appState.prepareAllPendingAssessments()
        XCTAssertNil(result1, "批次中断时返回 nil")
        XCTAssertEqual(appState.preparedVerificationKnowledgeCount, 10, "第一批的 10 个知识点应当成功持久化")
        XCTAssertNotNil(appState.preparedDomainAssessment(for: "Swift"), "已成功的第一批知识点题包应当可以正常获取")

        // Second attempt with normal client: only prepares remaining 23 nodes (2 balanced batches)
        let normalClient = AssessmentStubClient(validItemCount: 5)
        let appState2 = AppState(modelContainer: container, aiClient: normalClient)
        appState2.reload()
        appState2.setActiveEndpoint(endpoint.id)

        _ = await appState2.prepareAllPendingAssessments()
        let genCount2 = await normalClient.generationCount()
        XCTAssertEqual(genCount2, 2, "续备时只请求剩余未准备的 23 个知识点，产生 2 次 API 调用")
        XCTAssertEqual(appState2.preparedVerificationKnowledgeCount, 33, "全部 33 个知识点准备完成")
    }

    func testEmbeddedAssessmentPackageDoesNotFalselyDeduplicateAcrossMultipleSessions() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container)
        let nodeA = KnowledgeNode(name: "Actor", domain: "Swift", isProvisional: false)
        let nodeB = KnowledgeNode(name: "Sendable", domain: "Swift", isProvisional: false)
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)

        let packageItemA = AssessmentPackage.Item(
            knowledgeNodeID: nodeA.id,
            tier: .foundational,
            stem: "Stem A",
            answerOptions: ["A", "B", "C", "D"],
            correctAnswerIndex: 0,
            reasoningPrompt: "Reason A",
            reasoningOptions: ["R1", "R2", "R3", "R4"],
            correctReasoningIndex: 0,
            explanation: "Expl A",
            misconceptionTags: [],
            sourceActivityIDs: []
        )
        let packageItemB = AssessmentPackage.Item(
            knowledgeNodeID: nodeB.id,
            tier: .foundational,
            stem: "Stem B",
            answerOptions: ["A", "B", "C", "D"],
            correctAnswerIndex: 0,
            reasoningPrompt: "Reason B",
            reasoningOptions: ["R1", "R2", "R3", "R4"],
            correctReasoningIndex: 0,
            explanation: "Expl B",
            misconceptionTags: [],
            sourceActivityIDs: []
        )

        // Session 1 only covers Node A
        let session1 = AssessmentSession(knowledgeNodeID: nodeA.id, kind: .baseline, generatorModelID: "manual")
        let item1 = AssessmentItem(sessionID: session1.id, item: packageItemA)

        // Session 2 only covers Node B
        let session2 = AssessmentSession(knowledgeNodeID: nodeB.id, kind: .baseline, generatorModelID: "manual")
        let item2 = AssessmentItem(sessionID: session2.id, item: packageItemB)

        container.mainContext.insert(session1)
        container.mainContext.insert(item1)
        container.mainContext.insert(session2)
        container.mainContext.insert(item2)
        try container.mainContext.save()
        appState.reload()

        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .markdownDirectory,
            timestamp: .now,
            fingerprint: "fp",
            contentChangeHash: "hash",
            title: "Title",
            sourceLocator: "test.md",
            summary: "Summary",
            excerpt: "Excerpt"
        )
        container.mainContext.insert(activity)
        try container.mainContext.save()
        appState.reload()

        let embedded = makeEmbeddedPackage(nodes: [nodeA, nodeB], activityID: activity.id)
        let persisted = try appState.persistEmbeddedAssessmentPackage(embedded, activities: [activity], generatorModelID: "m")

        XCTAssertNotEqual(persisted.id, session1.id, "不能因为多个 Session 的并集覆盖就误复用 Session 1")
        XCTAssertNotEqual(persisted.id, session2.id, "不能因为多个 Session 的并集覆盖就误复用 Session 2")
    }

    func testEmbeddedAssessmentPackageReusesSingleSessionCoveringAllTargetNodes() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container)
        let nodeA = KnowledgeNode(name: "Actor", domain: "Swift", isProvisional: false)
        let nodeB = KnowledgeNode(name: "Sendable", domain: "Swift", isProvisional: false)
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)

        let packageItemA = AssessmentPackage.Item(
            knowledgeNodeID: nodeA.id,
            tier: .foundational,
            stem: "Stem A",
            answerOptions: ["A", "B", "C", "D"],
            correctAnswerIndex: 0,
            reasoningPrompt: "Reason A",
            reasoningOptions: ["R1", "R2", "R3", "R4"],
            correctReasoningIndex: 0,
            explanation: "Expl A",
            misconceptionTags: [],
            sourceActivityIDs: []
        )
        let packageItemB = AssessmentPackage.Item(
            knowledgeNodeID: nodeB.id,
            tier: .foundational,
            stem: "Stem B",
            answerOptions: ["A", "B", "C", "D"],
            correctAnswerIndex: 0,
            reasoningPrompt: "Reason B",
            reasoningOptions: ["R1", "R2", "R3", "R4"],
            correctReasoningIndex: 0,
            explanation: "Expl B",
            misconceptionTags: [],
            sourceActivityIDs: []
        )

        // Session covers BOTH Node A and Node B
        let session = AssessmentSession(knowledgeNodeID: nodeA.id, kind: .baseline, generatorModelID: "manual")
        let item1 = AssessmentItem(sessionID: session.id, item: packageItemA)
        let item2 = AssessmentItem(sessionID: session.id, item: packageItemB)

        container.mainContext.insert(session)
        container.mainContext.insert(item1)
        container.mainContext.insert(item2)

        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .markdownDirectory,
            timestamp: .now,
            fingerprint: "fp",
            contentChangeHash: "hash",
            title: "Title",
            sourceLocator: "test.md",
            summary: "Summary",
            excerpt: "Excerpt"
        )
        container.mainContext.insert(activity)
        try container.mainContext.save()
        appState.reload()

        let embedded = makeEmbeddedPackage(nodes: [nodeA, nodeB], activityID: activity.id)
        let persisted = try appState.persistEmbeddedAssessmentPackage(embedded, activities: [activity], generatorModelID: "m")

        XCTAssertEqual(persisted.id, session.id, "当单一 Session 完整覆盖所有目标知识点时，应当正确复用")
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
    private let interruptedBatchCalls: Set<Int>
    private var calls = 0
    private var singleCalls = 0
    private var batchCalls = 0
    private var capturedRequests: [AssessmentRequest] = []
    private var capturedBatchSizes: [Int] = []
    private var capturedAttemptedBatchSizes: [Int] = []

    init(
        validItemCount: Int,
        failingBatchCall: Int? = nil,
        incompatibleBatchCall: Int? = nil,
        interruptedBatchCalls: Set<Int> = []
    ) {
        self.validItemCount = validItemCount
        self.failingBatchCall = failingBatchCall
        self.incompatibleBatchCall = incompatibleBatchCall
        self.interruptedBatchCalls = interruptedBatchCalls
    }

    func generationCount() -> Int { calls }
    func singleGenerationCount() -> Int { singleCalls }
    func batchGenerationCount() -> Int { batchCalls }
    func requests() -> [AssessmentRequest] { capturedRequests }
    func batchSizes() -> [Int] { capturedBatchSizes }
    func attemptedBatchSizes() -> [Int] { capturedAttemptedBatchSizes }

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
        capturedAttemptedBatchSizes.append(requests.reduce(0) { $0 + $1.targetKnowledgeNodes.count })
        if calls == incompatibleBatchCall {
            throw AssessmentGenerationError.batchFormatIncompatible("缺少字段 packages[0].items")
        }
        if interruptedBatchCalls.contains(calls) {
            throw AssessmentGenerationError.transportInterrupted("连接在等待 AI 完整响应时被代理断开")
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
