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

    func testActivityFeedUsesBoundedSwiftDataFetchAndDatabaseFilters() throws {
        for index in 0..<220 {
            container.mainContext.insert(
                ActivityEvent(
                    sourceID: UUID(),
                    sourceKind: .manual,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                    fingerprint: "feed-\(index)",
                    title: index == 17 ? "needle activity" : "activity \(index)",
                    sourceLocator: "manual:\(index)",
                    summary: "summary",
                    excerpt: "excerpt",
                    isProcessed: index.isMultiple(of: 2)
                )
            )
        }
        try container.mainContext.save()
        appState.reload()

        XCTAssertEqual(appState.totalActivityCount, 220)
        XCTAssertEqual(appState.pendingActivityCount, 110)
        XCTAssertEqual(appState.activityEvents.count, 200)

        appState.loadActivityFeed(filter: .pending, searchText: "", limit: 10)
        XCTAssertEqual(appState.activityFeedTotalCount, 110)
        XCTAssertEqual(appState.activityFeedEvents.count, 10)
        XCTAssertTrue(appState.activityFeedEvents.allSatisfy { !$0.isProcessed })

        appState.loadActivityFeed(filter: .all, searchText: "needle", limit: 50)
        XCTAssertEqual(appState.activityFeedTotalCount, 1)
        XCTAssertEqual(appState.activityFeedEvents.map(\.title), ["needle activity"])
    }

    func testTodayActivityCountUsesDatabaseCountBeyondRecentActivityCache() throws {
        let now = Date.now
        for index in 0..<220 {
            container.mainContext.insert(
                ActivityEvent(
                    sourceID: UUID(),
                    sourceKind: .manual,
                    timestamp: now,
                    fingerprint: "today-count-\(index)",
                    title: "today \(index)",
                    sourceLocator: "manual:today:\(index)",
                    summary: "summary",
                    excerpt: "excerpt"
                )
            )
        }
        container.mainContext.insert(
            ActivityEvent(
                sourceID: UUID(),
                sourceKind: .manual,
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
                fingerprint: "yesterday-count",
                title: "yesterday",
                sourceLocator: "manual:yesterday",
                summary: "summary",
                excerpt: "excerpt"
            )
        )
        try container.mainContext.save()

        appState.reload()

        XCTAssertEqual(appState.todayActivityCount, 220)
        XCTAssertEqual(appState.activityEvents.count, 200)
    }

    func testStatusMessageDismissalDoesNotLetOldTimerClearNewMessage() async throws {
        let transientState = AppState(
            modelContainer: container,
            statusMessageSuccessDuration: .milliseconds(50),
            statusMessageErrorDuration: .milliseconds(100)
        )

        transientState.statusMessage = "第一条消息"
        try await Task.sleep(for: .milliseconds(25))
        transientState.statusMessage = "第二条消息"
        try await Task.sleep(for: .milliseconds(35))

        XCTAssertEqual(transientState.statusMessage, "第二条消息")

        try await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(transientState.statusMessage)
    }

    func testAnalysisProgressMessageRemainsUntilAnalysisFinishes() async throws {
        let transientState = AppState(
            modelContainer: container,
            aiClient: DelayedAnalysisStubClient(),
            statusMessageSuccessDuration: .milliseconds(30),
            statusMessageErrorDuration: .milliseconds(60)
        )
        let endpoint = AIEndpointProfile(
            name: "测试接口",
            baseURLString: "https://mock.local/v1",
            selectedModelID: "mock"
        )
        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .manual,
            timestamp: .now,
            fingerprint: "persistent-analysis-progress",
            title: "分析进度测试",
            sourceLocator: "manual:analysis-progress",
            summary: "验证分析进度不会被普通提示覆盖",
            excerpt: "分析进度"
        )
        container.mainContext.insert(endpoint)
        container.mainContext.insert(activity)
        try container.mainContext.save()
        transientState.reload()
        transientState.setActiveEndpoint(endpoint.id)

        let analysisTask = Task { await transientState.runAnalysis() }
        for _ in 0..<40 where transientState.analysisProgressMessage == nil {
            try await Task.sleep(for: .milliseconds(5))
        }
        _ = try XCTUnwrap(transientState.analysisProgressMessage)

        transientState.statusMessage = "自动采集完成"
        try await Task.sleep(for: .milliseconds(60))

        XCTAssertNotNil(transientState.analysisProgressMessage)
        XCTAssertEqual(transientState.presentedStatusMessage, transientState.analysisProgressMessage)

        await analysisTask.value

        XCTAssertNil(transientState.analysisProgressMessage)
        XCTAssertEqual(transientState.statusMessage, "已成功分析 1 条活动")
    }

    func testStoppingTrackingRemovesPendingNoteAndPreventsRescan() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let noteURL = directory.appending(path: "ignored-note.md")
        try "# 不需要的笔记\n首次内容".write(to: noteURL, atomically: true, encoding: .utf8)

        try appState.addSource(name: "测试笔记", kind: .markdownDirectory, path: directory.path)
        try await appState.scanSources()
        guard let activity = appState.activityEvents.first(where: {
            URL(fileURLWithPath: $0.sourceLocator).lastPathComponent == noteURL.lastPathComponent
        }) else {
            return XCTFail("Expected the note to be collected")
        }
        XCTAssertEqual(appState.pendingActivityCount, 1)

        try appState.stopTracking(activityIDs: Set([activity.id]))

        XCTAssertEqual(appState.pendingActivityCount, 0)
        XCTAssertFalse(appState.activityEvents.contains { $0.id == activity.id })
        XCTAssertEqual(appState.activityTrackingExclusions.map(\.sourceLocator), [activity.sourceLocator])

        try "# 不需要的笔记\n更新后也不应再次收录".write(to: noteURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(5)],
            ofItemAtPath: noteURL.path
        )
        try await appState.scanSources()

        XCTAssertEqual(appState.totalActivityCount, 0)
        XCTAssertFalse(appState.activityEvents.contains {
            URL(fileURLWithPath: $0.sourceLocator).lastPathComponent == noteURL.lastPathComponent
        })
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
            evidenceID: evidence.id,
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

    func testApprovingSuggestionVerifiesOnlyItsLinkedEvidence() {
        let node = KnowledgeNode(name: "Linux 进程", domain: "嵌入式 Linux", isProvisional: false)
        let state = MasteryState(knowledgeNodeID: node.id)
        let activityA = UUID()
        let activityB = UUID()
        let evidenceA = EvidenceRecord(
            activityID: activityA,
            knowledgeNodeID: node.id,
            kind: .explanation,
            timestamp: .now.addingTimeInterval(-60),
            summary: "证据 A",
            rationale: "记录父进程概念",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.72,
            isVerified: false,
            fingerprint: "same-node-evidence-a"
        )
        let evidenceB = EvidenceRecord(
            activityID: activityB,
            knowledgeNodeID: node.id,
            kind: .project,
            timestamp: .now,
            summary: "证据 B",
            rationale: "实践进程创建",
            difficulty: 1,
            independence: 1,
            aiConfidence: 0.78,
            isVerified: false,
            fingerprint: "same-node-evidence-b"
        )
        let suggestionA = TaxonomySuggestion(
            suggestionType: "reviewEvidence",
            proposedName: node.name,
            relatedNodeID: node.id,
            activityID: activityA,
            evidenceID: evidenceA.id,
            rationale: "审核 A",
            confidence: 0.72
        )
        let suggestionB = TaxonomySuggestion(
            suggestionType: "reviewEvidence",
            proposedName: node.name,
            relatedNodeID: node.id,
            activityID: activityB,
            evidenceID: evidenceB.id,
            rationale: "审核 B",
            confidence: 0.78
        )

        for model in [node, state, evidenceA, evidenceB, suggestionA, suggestionB] as [any PersistentModel] {
            appState.modelContainer.mainContext.insert(model)
        }
        try? appState.modelContainer.mainContext.save()
        appState.reload()

        appState.approveSuggestion(suggestionB)

        XCTAssertFalse(evidenceA.isVerified)
        XCTAssertTrue(evidenceB.isVerified)
        XCTAssertEqual(suggestionA.status, "pending")
        XCTAssertEqual(suggestionB.status, "approved")
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
            evidenceID: evidence.id,
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
            evidenceID: evidence.id,
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

    func testScheduleReviewPersistsRealReviewPlan() throws {
        let node = KnowledgeNode(name: "Linux 进程", domain: "Linux", isProvisional: false)
        appState.modelContainer.mainContext.insert(node)
        try appState.modelContainer.mainContext.save()
        appState.reload()
        let scheduledAt = Date.now.addingTimeInterval(7 * 86_400)

        try appState.scheduleReview(
            for: node.id,
            scheduledAt: scheduledAt,
            reason: "用户主动安排"
        )

        let plans = appState.reviewPlans(for: node.id)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].scheduledAt, scheduledAt)
        XCTAssertEqual(plans[0].reason, "用户主动安排")
        XCTAssertEqual(plans[0].status, "scheduled")
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

    func testLowInformationCodeChangeCannotCreateHighValuePracticeEvidence() throws {
        let node = KnowledgeNode(name: "C 格式化", domain: "C / 系统编程")
        let state = MasteryState(knowledgeNodeID: node.id)
        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .remoteGitRepository,
            timestamp: .now,
            fingerprint: "format-only-code",
            contentChangeHash: "format-only-hash",
            title: "统一格式",
            sourceLocator: "/repo#abc:code",
            summary: "[低信息代码变更] 1 个代码文件 · commit abc",
            excerpt: "-int main(){return 0;}\n+int main() { return 0; }"
        )
        let analyzed = AnalyzedEvidence(
            activityID: activity.id,
            knowledgeName: node.name,
            matchedNodeID: node.id,
            matchConfidence: 0.95,
            kind: .project,
            difficulty: 1.5,
            independence: 1,
            confidence: 0.95,
            summary: "格式化代码",
            rationale: "没有实质实现"
        )
        let envelope = AnalysisEnvelope(
            sessionSummary: "低信息变更",
            evidence: [analyzed],
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: nil
        )
        let run = AnalysisRun(endpointProfileID: nil, modelID: "mock", activityCount: 1)
        appState.modelContainer.mainContext.insert(node)
        appState.modelContainer.mainContext.insert(state)
        appState.modelContainer.mainContext.insert(activity)
        appState.modelContainer.mainContext.insert(run)
        try appState.modelContainer.mainContext.save()
        appState.reload()

        let awardedXP = try appState.apply(envelope: envelope, to: [activity], analysisRun: run)
        try appState.modelContainer.mainContext.save()
        appState.reload()

        XCTAssertEqual(awardedXP, 0)
        XCTAssertFalse(appState.evidenceRecords.contains { $0.activityID == activity.id })
        XCTAssertEqual(appState.mastery(for: node.id)?.lifetimeXP, 0)
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

    func testAppStateRepairsStaleActiveEndpointSelection() throws {
        let defaults = UserDefaults.standard
        let previousValue = defaults.string(forKey: "activeEndpointID")
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: "activeEndpointID")
            } else {
                defaults.removeObject(forKey: "activeEndpointID")
            }
        }

        let profile = AIEndpointProfile(
            name: "已配置接口",
            baseURLString: "https://mock.local/v1",
            selectedModelID: "mock"
        )
        appState.modelContainer.mainContext.insert(profile)
        try appState.modelContainer.mainContext.save()
        defaults.set(UUID().uuidString, forKey: "activeEndpointID")

        let repairedState = AppState(modelContainer: container)

        XCTAssertEqual(repairedState.activeEndpointID, profile.id)
        XCTAssertEqual(repairedState.activeEndpoint?.id, profile.id)
    }

    func testSavingNewEndpointPreservesDraftIDAndMakesItActive() async throws {
        let defaults = UserDefaults.standard
        let previousValue = defaults.string(forKey: "activeEndpointID")
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: "activeEndpointID")
            } else {
                defaults.removeObject(forKey: "activeEndpointID")
            }
        }
        defaults.set(UUID().uuidString, forKey: "activeEndpointID")
        let draft = EndpointDraft(
            name: "新接口",
            baseURLString: "https://mock.local/v1",
            selectedModelID: "mock"
        )

        try await appState.saveEndpoint(draft)

        XCTAssertEqual(appState.endpointProfiles.count, 1)
        XCTAssertEqual(appState.endpointProfiles.first?.id, draft.id)
        XCTAssertEqual(appState.activeEndpointID, draft.id)
    }

    func testBulkApproveSuggestionsProcessesRelationsWithProvenanceAndCycleChecking() {
        let nodeA = KnowledgeNode(name: "概念 A", domain: "测试")
        let nodeB = KnowledgeNode(name: "概念 B", domain: "测试")
        let nodeC = KnowledgeNode(name: "概念 C", domain: "测试")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)
        container.mainContext.insert(nodeC)

        // 建立 A -> B 建议（合法）
        let suggAB = TaxonomySuggestion(
            suggestionType: "relation",
            proposedName: "概念 A → 先修先导 → 概念 B",
            rationale: "A 是 B 的前置",
            confidence: 0.9,
            sourceNodeID: nodeA.id,
            targetNodeID: nodeB.id,
            relationRawValue: "prerequisite"
        )
        // 建立 B -> C 建议（合法）
        let suggBC = TaxonomySuggestion(
            suggestionType: "relation",
            proposedName: "概念 B → 先修先导 → 概念 C",
            rationale: "B 是 C 的前置",
            confidence: 0.9,
            sourceNodeID: nodeB.id,
            targetNodeID: nodeC.id,
            relationRawValue: "prerequisite"
        )
        container.mainContext.insert(suggAB)
        container.mainContext.insert(suggBC)
        try? container.mainContext.save()
        appState.reload()

        XCTAssertEqual(appState.knowledgeEdges.count, 0)
        XCTAssertEqual(appState.taxonomySuggestions.count, 2)

        // 批量批准
        appState.approveAllPendingSuggestions()

        XCTAssertEqual(appState.knowledgeEdges.count, 2)
        XCTAssertTrue(appState.knowledgeEdges.allSatisfy { $0.origin == "userConfirmed" })
        XCTAssertTrue(appState.knowledgeEdges.allSatisfy { $0.confirmedAt != nil })
        XCTAssertEqual(suggAB.status, "approved")
        XCTAssertEqual(suggBC.status, "approved")
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

private struct DelayedAnalysisStubClient: AIProviderClient {
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
        try await Task.sleep(for: .milliseconds(150))
        return AnalysisEnvelope(
            sessionSummary: "分析完成",
            evidence: [],
            nodeSuggestions: [],
            edgeSuggestions: [],
            challengeSuggestion: nil
        )
    }
}
