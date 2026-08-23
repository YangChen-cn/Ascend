import AppKit
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    let modelContainer: ModelContainer
    private let modelContext: ModelContext

    var selectedSection: NavigationSection = .today
    var isCollecting = true
    var isAnalyzing = false
    var statusMessage: String? {
        didSet { scheduleStatusMessageDismissal() }
    }
    var endpointProfiles: [AIEndpointProfile] = []
    var sources: [SourceConfiguration] = []
    var activityTrackingExclusions: [ActivityTrackingExclusion] = []
    var activityEvents: [ActivityEvent] = []
    private(set) var activityFeedEvents: [ActivityEvent] = []
    private(set) var activityFeedTotalCount = 0
    private(set) var totalActivityCount = 0
    private(set) var pendingActivityCount = 0
    var evidenceRecords: [EvidenceRecord] = []
    var knowledgeNodes: [KnowledgeNode] = []
    var masteryStates: [MasteryState] = []
    var knowledgeEdges: [KnowledgeEdge] = []
    var scoreLedgerEntries: [ScoreLedgerEntry] = []
    var challenges: [Challenge] = []
    var digests: [DailyDigest] = []
    var taxonomySuggestions: [TaxonomySuggestion] = []
    var reviewPlans: [ReviewPlan] = []
    var activeEndpointID: UUID?
    var selectedKnowledgeNodeID: UUID?
    var selectedSettingsSection: SettingsSection = .general

    private(set) var domainProgress: [DomainProgressSnapshot] = []
    private(set) var todayMasteryChanges: [DashboardMetric] = []
    private(set) var todayXPGains: [XPGainItem] = []
    private(set) var forgettingProjections: [ForgettingProjection] = []

    @ObservationIgnored private let aiClient: any AIProviderClient
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let scoringEngine: ScoringEngine
    @ObservationIgnored private let analyticsEngine: AnalyticsEngine
    @ObservationIgnored private let gitConnector: GitActivityConnector
    @ObservationIgnored private let markdownConnector: MarkdownActivityConnector
    @ObservationIgnored private let digestScheduler: DigestScheduler
    @ObservationIgnored private let statusMessageSuccessDuration: Duration
    @ObservationIgnored private let statusMessageErrorDuration: Duration
    @ObservationIgnored private var nodeByID: [UUID: KnowledgeNode] = [:]
    @ObservationIgnored private var masteryByNodeID: [UUID: MasteryState] = [:]
    @ObservationIgnored private var evidenceByID: [UUID: EvidenceRecord] = [:]
    @ObservationIgnored private var evidenceByNodeID: [UUID: [EvidenceRecord]] = [:]
    @ObservationIgnored private var ledgerByNodeID: [UUID: [ScoreLedgerEntry]] = [:]
    @ObservationIgnored private var statusMessageDismissalTask: Task<Void, Never>?

    init(
        modelContainer: ModelContainer,
        aiClient: any AIProviderClient = OpenAICompatibleClient(),
        keychain: KeychainStore = .shared,
        scoringEngine: ScoringEngine = ScoringEngine(),
        analyticsEngine: AnalyticsEngine = AnalyticsEngine(),
        gitConnector: GitActivityConnector = GitActivityConnector(),
        markdownConnector: MarkdownActivityConnector = MarkdownActivityConnector(),
        digestScheduler: DigestScheduler = DigestScheduler(),
        statusMessageSuccessDuration: Duration = .seconds(5),
        statusMessageErrorDuration: Duration = .seconds(10)
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
        self.aiClient = aiClient
        self.keychain = keychain
        self.scoringEngine = scoringEngine
        self.analyticsEngine = analyticsEngine
        self.gitConnector = gitConnector
        self.markdownConnector = markdownConnector
        self.digestScheduler = digestScheduler
        self.statusMessageSuccessDuration = statusMessageSuccessDuration
        self.statusMessageErrorDuration = statusMessageErrorDuration
        if let storedID = UserDefaults.standard.string(forKey: "activeEndpointID") {
            activeEndpointID = UUID(uuidString: storedID)
        }
        load()
        cleanupLegacyDemoDataIfNeeded()
        cleanupUnverifiedChallengeCompletionIfNeeded()
        load()
        selectedKnowledgeNodeID = knowledgeNodes.first?.id
    }

    var activeEndpoint: AIEndpointProfile? {
        endpointProfiles.first { $0.id == activeEndpointID }
    }

    var totalXP: Int {
        masteryStates.reduce(0) { $0 + $1.lifetimeXP }
    }

    var learnerLevel: Int {
        max(1, Int(Double(totalXP).squareRoot() / 3) + 1)
    }

    var currentDigest: DailyDigest? { digests.first }

    var pendingReviewCount: Int {
        taxonomySuggestions.count { $0.status == "pending" }
    }

    var domainNames: [String] {
        domainProgress.map(\.name)
    }

    func mastery(for nodeID: UUID) -> MasteryState? {
        masteryByNodeID[nodeID]
    }

    func readiness(for nodeID: UUID, now: Date = .now) -> MasteryReadinessSnapshot? {
        guard let state = mastery(for: nodeID) else { return nil }
        let current = scoringEngine.projectDecay(
            state.vector,
            stabilityDays: state.stabilityDays,
            lastEvidenceAt: state.lastEvidenceAt,
            now: now
        )
        return MasteryReadinessSnapshot(
            knowledgeNodeID: nodeID,
            historicalVector: state.vector,
            currentVector: current,
            historicalStage: state.highestStage,
            currentStage: MasteryStage.stage(for: current.composite)
        )
    }

    func ledgerEntries(for nodeID: UUID) -> [ScoreLedgerEntry] {
        ledgerByNodeID[nodeID] ?? []
    }

    func evidenceRecords(for nodeID: UUID) -> [EvidenceRecord] {
        evidenceByNodeID[nodeID] ?? []
    }

    func scheduleReview(
        for nodeID: UUID,
        scheduledAt: Date,
        reason: String
    ) throws {
        guard node(for: nodeID) != nil else { throw AppStateError.missingKnowledgeNode }
        let plan = ReviewPlan(
            knowledgeNodeID: nodeID,
            scheduledAt: scheduledAt,
            reason: reason
        )
        modelContext.insert(plan)
        try modelContext.save()
        reviewPlans.insert(plan, at: 0)
        statusMessage = "已安排真实复习计划：\(scheduledAt.formatted(date: .abbreviated, time: .shortened))"
    }

    func reviewPlans(for nodeID: UUID) -> [ReviewPlan] {
        reviewPlans
            .filter { $0.knowledgeNodeID == nodeID }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    func node(for nodeID: UUID) -> KnowledgeNode? {
        nodeByID[nodeID]
    }

    func latestInsight(for nodeID: UUID) -> String? {
        evidenceByNodeID[nodeID]?.first(where: \.isVerified)?.summary
    }

    func weeklyChange(for nodeID: UUID) -> Int {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        return Int((ledgerByNodeID[nodeID] ?? [])
            .filter { $0.timestamp >= start }
            .reduce(0) { $0 + max(0, $1.newComposite - $1.previousComposite) }
            .rounded())
    }

    func loadActivityFeed(
        filter: ActivityFeedFilter,
        searchText: String,
        limit: Int
    ) {
        do {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            var descriptor: FetchDescriptor<ActivityEvent>
            switch (filter, query.isEmpty) {
            case (.all, true):
                descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            case (.pending, true):
                descriptor = FetchDescriptor(
                    predicate: #Predicate { !$0.isProcessed },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            case (.processed, true):
                descriptor = FetchDescriptor(
                    predicate: #Predicate { $0.isProcessed },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            case (.all, false):
                descriptor = FetchDescriptor(
                    predicate: #Predicate {
                        $0.title.localizedStandardContains(query) ||
                            $0.summary.localizedStandardContains(query) ||
                            $0.sourceLocator.localizedStandardContains(query)
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            case (.pending, false):
                descriptor = FetchDescriptor(
                    predicate: #Predicate {
                        !$0.isProcessed &&
                            ($0.title.localizedStandardContains(query) ||
                                $0.summary.localizedStandardContains(query) ||
                                $0.sourceLocator.localizedStandardContains(query))
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            case (.processed, false):
                descriptor = FetchDescriptor(
                    predicate: #Predicate {
                        $0.isProcessed &&
                            ($0.title.localizedStandardContains(query) ||
                                $0.summary.localizedStandardContains(query) ||
                                $0.sourceLocator.localizedStandardContains(query))
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            }
            activityFeedTotalCount = try modelContext.fetchCount(descriptor)
            descriptor.fetchLimit = max(1, limit)
            activityFeedEvents = try modelContext.fetch(descriptor)
        } catch {
            statusMessage = "读取资料流失败：\(error.localizedDescription)"
        }
    }

    func setActiveEndpoint(_ id: UUID?) {
        activeEndpointID = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: "activeEndpointID")
        } else {
            UserDefaults.standard.removeObject(forKey: "activeEndpointID")
        }
    }

    func selectModel(profileID: UUID, modelID: String) {
        guard let profile = endpointProfiles.first(where: { $0.id == profileID }) else { return }
        profile.selectedModelID = modelID
        profile.lastConnectedAt = .now
        try? modelContext.save()
        setActiveEndpoint(profileID)
    }

    func draft(for profile: AIEndpointProfile?) -> EndpointDraft {
        guard let profile else { return EndpointDraft() }
        return EndpointDraft(
            id: profile.id,
            name: profile.name,
            baseURLString: profile.baseURLString,
            selectedModelID: profile.selectedModelID,
            cachedModelIDs: profile.cachedModelIDs,
            isEnabled: profile.isEnabled
        )
    }

    func connect(_ draft: EndpointDraft) async throws -> [RemoteModel] {
        let baseURL = try EndpointURLBuilder().normalizedBaseURL(from: draft.baseURLString)
        let key = try await resolvedAPIKey(draft: draft)
        let endpoint = AIEndpointDescriptor(
            id: draft.id,
            name: draft.name,
            baseURL: baseURL,
            selectedModelID: draft.selectedModelID,
            supportsStructuredOutputs: nil
        )
        AppLogger.ai.info("Fetching model list for endpoint \(draft.name, privacy: .public)")
        return try await aiClient.listModels(endpoint: endpoint, apiKey: key)
    }

    func test(_ draft: EndpointDraft) async throws {
        let baseURL = try EndpointURLBuilder().normalizedBaseURL(from: draft.baseURLString)
        guard !draft.selectedModelID.isEmpty else {
            throw AppStateError.missingModel
        }
        let endpoint = AIEndpointDescriptor(
            id: draft.id,
            name: draft.name,
            baseURL: baseURL,
            selectedModelID: draft.selectedModelID,
            supportsStructuredOutputs: nil
        )
        try await aiClient.test(
            endpoint: endpoint,
            modelID: draft.selectedModelID,
            apiKey: try await resolvedAPIKey(draft: draft)
        )
    }

    func saveEndpoint(_ draft: EndpointDraft) async throws {
        _ = try EndpointURLBuilder().normalizedBaseURL(from: draft.baseURLString)
        let profile = endpointProfiles.first { $0.id == draft.id }
        let target = profile ?? AIEndpointProfile(
            id: draft.id,
            name: draft.name,
            baseURLString: draft.baseURLString
        )
        target.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.baseURLString = draft.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        target.selectedModelID = draft.selectedModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        target.setCachedModelIDs(draft.cachedModelIDs)
        target.isEnabled = draft.isEnabled
        target.lastError = nil
        if profile == nil { modelContext.insert(target) }
        if !draft.apiKey.isEmpty {
            try await keychain.saveAPIKey(draft.apiKey, endpointID: target.id)
        }
        try modelContext.save()
        if profile == nil {
            endpointProfiles.append(target)
            endpointProfiles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        if activeEndpoint == nil { setActiveEndpoint(target.id) }
    }

    func deleteEndpoint(_ profile: AIEndpointProfile) async throws {
        modelContext.delete(profile)
        try modelContext.save()
        try await keychain.deleteAPIKey(endpointID: profile.id)
        if activeEndpointID == profile.id { setActiveEndpoint(endpointProfiles.first { $0.id != profile.id }?.id) }
        endpointProfiles.removeAll { $0.id == profile.id }
    }

    func addSource(name: String, kind: SourceKind, path: String) throws {
        guard !sources.contains(where: { $0.path == path && $0.kind == kind }) else {
            throw AppStateError.duplicateSource
        }
        let source = SourceConfiguration(name: name, kind: kind, path: path)
        modelContext.insert(source)
        try modelContext.save()
        sources.append(source)
        sources.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func deleteSource(_ source: SourceConfiguration) throws {
        modelContext.delete(source)
        try modelContext.save()
        sources.removeAll { $0.id == source.id }
    }

    func renameDomain(_ sourceName: String, to proposedName: String) throws {
        let targetName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetName.isEmpty else { throw AppStateError.invalidDomainName }
        let sourceNodes = nodes(inDomain: sourceName)
        guard !sourceNodes.isEmpty else { throw AppStateError.missingDomain }
        if sourceName == targetName {
            return
        }
        guard !domainNames.contains(where: {
            $0 != sourceName && $0.localizedStandardCompare(targetName) == .orderedSame
        }) else {
            throw AppStateError.duplicateDomain
        }
        sourceNodes.forEach {
            $0.domain = targetName
            $0.updatedAt = .now
        }
        try modelContext.save()
        updateSnapshots()
        statusMessage = "已将领域“\(sourceName)”重命名为“\(targetName)”"
    }

    func mergeDomain(_ sourceName: String, into targetName: String) throws {
        guard sourceName.localizedStandardCompare(targetName) != .orderedSame else {
            throw AppStateError.sameDomain
        }
        let sourceNodes = nodes(inDomain: sourceName)
        guard !sourceNodes.isEmpty else { throw AppStateError.missingDomain }
        guard let resolvedTarget = domainNames.first(where: {
            $0.localizedStandardCompare(targetName) == .orderedSame
        }) else {
            throw AppStateError.missingDomain
        }
        sourceNodes.forEach {
            $0.domain = resolvedTarget
            $0.updatedAt = .now
        }
        try modelContext.save()
        updateSnapshots()
        statusMessage = "已将领域“\(sourceName)”合并至“\(resolvedTarget)”"
    }

    func deleteDomain(_ domainName: String, strategy: DomainDeletionStrategy) throws {
        let domainNodes = nodes(inDomain: domainName)
        guard !domainNodes.isEmpty else { throw AppStateError.missingDomain }
        let successMessage: String

        switch strategy {
        case .moveKnowledgeToUncategorized:
            guard domainName.localizedStandardCompare("待分类") != .orderedSame else {
                throw AppStateError.sameDomain
            }
            domainNodes.forEach {
                $0.domain = "待分类"
                $0.updatedAt = .now
            }
            successMessage = "已删除领域“\(domainName)”，知识点已移至“待分类”"

        case .deleteKnowledge:
            let nodeIDs = Set(domainNodes.map(\.id))
            let removedEvidence = evidenceRecords.filter { nodeIDs.contains($0.knowledgeNodeID) }
            let removedEvidenceIDs = Set(removedEvidence.map(\.id))
            let affectedActivityIDs = Set(removedEvidence.map(\.activityID))
            let remainingEvidence = evidenceRecords.filter { !removedEvidenceIDs.contains($0.id) }

            knowledgeEdges
                .filter { nodeIDs.contains($0.sourceNodeID) || nodeIDs.contains($0.targetNodeID) }
                .forEach(modelContext.delete)
            scoreLedgerEntries
                .filter { nodeIDs.contains($0.knowledgeNodeID) || removedEvidenceIDs.contains($0.evidenceID) }
                .forEach(modelContext.delete)
            taxonomySuggestions
                .filter { $0.relatedNodeID.map(nodeIDs.contains) == true }
                .forEach(modelContext.delete)
            challenges
                .filter { !nodeIDs.isDisjoint(with: Set($0.knowledgeNodeIDs)) }
                .forEach(modelContext.delete)
            masteryStates
                .filter { nodeIDs.contains($0.knowledgeNodeID) }
                .forEach(modelContext.delete)
            reviewPlans
                .filter { nodeIDs.contains($0.knowledgeNodeID) }
                .forEach(modelContext.delete)
            removedEvidence.forEach(modelContext.delete)
            domainNodes.forEach(modelContext.delete)

            let remainingActivityIDs = Set(remainingEvidence.map(\.activityID))
            let orphanedActivityIDs = affectedActivityIDs.subtracting(remainingActivityIDs)
            let orphanedActivities = try fetchActivities(ids: orphanedActivityIDs)
            for activity in orphanedActivities {
                createTrackingExclusion(for: activity, reason: "永久删除领域“\(domainName)”")
                modelContext.delete(activity)
            }
            if selectedKnowledgeNodeID.map(nodeIDs.contains) == true {
                selectedKnowledgeNodeID = nil
            }
            successMessage = "已永久删除领域“\(domainName)”及其 \(domainNodes.count) 个知识点"
        }

        try modelContext.save()
        load()
        statusMessage = successMessage
    }

    func nodes(inDomain domainName: String) -> [KnowledgeNode] {
        knowledgeNodes.filter { $0.domain.localizedStandardCompare(domainName) == .orderedSame }
    }

    func reload() {
        load()
    }

    func saveChanges() {
        do {
            try modelContext.save()
            refreshDerivedState()
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    func dismissStatusMessage() {
        statusMessage = nil
    }

    func scanSources() async throws {
        guard isCollecting else { return }
        let knownFingerprints = Set(try modelContext.fetch(FetchDescriptor<ActivityEvent>()).map(\.fingerprint))
        var insertedFingerprints = knownFingerprints
        var insertedEvents: [ActivityEvent] = []
        let excludedLocations = Set(activityTrackingExclusions.map(trackingKey))
        for source in sources where source.isEnabled && source.kind != .manual {
            let descriptor = SourceDescriptor(
                id: source.id,
                name: source.name,
                kind: source.kind,
                path: source.path,
                analyzeWorkingTree: source.analyzeWorkingTree,
                authorFilter: source.authorFilter,
                ignorePatterns: source.ignorePatterns,
                lastScannedAt: source.lastScannedAt,
                lastCursor: source.lastCursor
            )
            let result: ActivityScanResult
            switch source.kind {
            case .gitRepository:
                result = try await gitConnector.scan(source: descriptor)
            case .markdownDirectory:
                result = try await markdownConnector.scan(source: descriptor)
            case .manual:
                result = ActivityScanResult(activities: [])
            }
            for item in result.activities where
                !insertedFingerprints.contains(item.fingerprint) &&
                !excludedLocations.contains(trackingKey(sourceID: item.sourceID, sourceLocator: item.sourceLocator)) {
                let event = ActivityEvent(
                        id: item.id,
                        sourceID: item.sourceID,
                        sourceKind: item.sourceKind,
                        timestamp: item.timestamp,
                        fingerprint: item.fingerprint,
                        title: item.title,
                        sourceLocator: item.sourceLocator,
                        summary: item.summary,
                        excerpt: item.excerpt
                    )
                modelContext.insert(event)
                insertedEvents.append(event)
                insertedFingerprints.insert(item.fingerprint)
            }
            source.lastScannedAt = result.scannedAt
            if source.kind == .gitRepository {
                source.lastCursor = result.nextCursor
            }
            try modelContext.save()
        }
        activityEvents = Array((insertedEvents + activityEvents)
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(200))
        refreshActivityCounts()
        AppLogger.collector.info("Source scan completed with \(insertedEvents.count) new activities")
    }

    func runAnalysis(endpointOverride: UUID? = nil, modelOverride: String? = nil) async {
        await analyzeActivities(
            endpointOverride: endpointOverride,
            modelOverride: modelOverride,
            targetActivityIDs: nil,
            overwritesExistingResults: false
        )
    }

    func reanalyze(activityIDs: Set<UUID>) async {
        guard !activityIDs.isEmpty else { return }
        await analyzeActivities(
            endpointOverride: nil,
            modelOverride: nil,
            targetActivityIDs: activityIDs,
            overwritesExistingResults: true
        )
    }

    func stopTracking(activityIDs: Set<UUID>) throws {
        guard !activityIDs.isEmpty else { return }
        let selectedActivities = try fetchActivities(ids: activityIDs)
        guard !selectedActivities.isEmpty else { return }

        var activitiesByID: [UUID: ActivityEvent] = [:]
        for selected in selectedActivities {
            let sourceID = selected.sourceID
            let sourceLocator = selected.sourceLocator
            let descriptor = FetchDescriptor<ActivityEvent>(
                predicate: #Predicate {
                    $0.sourceID == sourceID && $0.sourceLocator == sourceLocator
                }
            )
            for activity in try modelContext.fetch(descriptor) {
                activitiesByID[activity.id] = activity
            }
        }
        let activities = Array(activitiesByID.values)

        removeExistingAnalysis(for: Set(activities.map(\.id)))
        for activity in selectedActivities {
            createTrackingExclusion(for: activity, reason: "用户从资料流删除跟踪")
        }
        for activity in activities {
            modelContext.delete(activity)
        }
        try modelContext.save()
        load()
        statusMessage = "已停止跟踪 \(selectedActivities.count) 个条目并删除 \(activities.count) 条活动；后续扫描不会再次收录"
    }

    private func analyzeActivities(
        endpointOverride: UUID?,
        modelOverride: String?,
        targetActivityIDs: Set<UUID>?,
        overwritesExistingResults: Bool
    ) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        statusMessage = nil
        defer { isAnalyzing = false }

        do {
            let preferences = AnalysisPreferences.current()
            if targetActivityIDs == nil && preferences.scansBeforeAnalysis {
                try await scanSources()
            }
            let selectedActivities = try fetchActivities(ids: targetActivityIDs)
            guard !selectedActivities.isEmpty else {
                statusMessage = "没有新的学习活动需要分析"
                return
            }
            let selectedProfileID = endpointOverride ?? activeEndpointID
            let profile = endpointProfiles.first(where: { $0.id == selectedProfileID })
                ?? endpointProfiles.first(where: { $0.isEnabled && !$0.selectedModelID.isEmpty })
                ?? endpointProfiles.first(where: \.isEnabled)
            guard let profile else {
                throw AppStateError.missingEndpoint
            }
            if endpointOverride == nil, activeEndpointID != profile.id {
                setActiveEndpoint(profile.id)
            }
            let modelID: String
            if let modelOverride, !modelOverride.isEmpty {
                modelID = modelOverride
            } else {
                modelID = profile.selectedModelID
            }
            guard !modelID.isEmpty else { throw AppStateError.missingModel }
            let baseURL = try EndpointURLBuilder().normalizedBaseURL(from: profile.baseURLString)
            let descriptor = AIEndpointDescriptor(
                id: profile.id,
                name: profile.name,
                baseURL: baseURL,
                selectedModelID: modelID,
                supportsStructuredOutputs: profile.supportsStructuredOutputs
            )
            let key = try await keychain.apiKey(endpointID: profile.id) ?? ""

            let batchSize = preferences.batchSize
            let batches = stride(from: 0, to: selectedActivities.count, by: batchSize).map {
                Array(selectedActivities[$0..<min($0 + batchSize, selectedActivities.count)])
            }
            let totalBatches = batches.count
            var lastSummary = ""

            for (index, batch) in batches.enumerated() {
                statusMessage = totalBatches > 1
                    ? "正在分析第 \(index + 1)/\(totalBatches) 批 (\(batch.count) 条活动)…"
                    : "正在分析学习活动…"

                let activities = batch.map { event in
                    CollectedActivity(
                        id: event.id,
                        sourceID: event.sourceID,
                        sourceKind: SourceKind(rawValue: event.sourceKindRawValue) ?? .manual,
                        timestamp: event.timestamp,
                        fingerprint: event.fingerprint,
                        title: event.title,
                        sourceLocator: event.sourceLocator,
                        summary: event.summary,
                        excerpt: event.excerpt
                    )
                }
                let candidates = knowledgeNodes.map { node in
                    KnowledgeCandidate(id: node.id, name: node.name, domain: node.domain, mastery: readiness(for: node.id)?.currentComposite ?? 0)
                }
                let run = AnalysisRun(
                    endpointProfileID: profile.id,
                    modelID: modelID,
                    activityCount: activities.count
                )
                modelContext.insert(run)
                try modelContext.save()

                do {
                    let envelope = try await aiClient.analyze(
                        endpoint: descriptor,
                        modelID: modelID,
                        apiKey: key,
                        activities: activities,
                        candidateNodes: candidates,
                        options: preferences.options
                    )
                    if overwritesExistingResults {
                        removeExistingAnalysis(for: Set(batch.map(\.id)))
                    }
                    _ = try apply(
                        envelope: envelope,
                        to: batch,
                        analysisRun: run,
                        createsAggregateResults: !overwritesExistingResults
                    )
                    lastSummary = envelope.sessionSummary
                    run.status = "completed"
                    run.completedAt = .now
                    try modelContext.save()
                    rebuildIndexes()
                    updateSnapshots()
                    refreshActivityCounts()
                } catch {
                    modelContext.rollback()
                    run.status = "failed"
                    run.errorMessage = error.localizedDescription
                    run.completedAt = .now
                    try modelContext.save()
                    load()
                    throw error
                }
            }

            statusMessage = overwritesExistingResults
                ? "已重新分析并覆盖 \(selectedActivities.count) 条活动"
                : "已成功分析 \(selectedActivities.count) 条活动"
            try? await digestScheduler.sendDigestReadyNotification(summary: lastSummary)
        } catch {
            statusMessage = error.localizedDescription
            AppLogger.ai.error("Analysis failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func configureNotifications(hour: Int, minute: Int) async throws {
        try await digestScheduler.requestAuthorization()
        try await digestScheduler.scheduleDailyDigest(hour: hour, minute: minute)
    }

    func exportJSON() throws -> Data {
        let bundle = ExportBundle(
            exportedAt: .now,
            knowledgeNodes: knowledgeNodes.map {
                ExportedKnowledgeNode(id: $0.id, name: $0.name, domain: $0.domain, parentID: $0.parentID, isProvisional: $0.isProvisional)
            },
            masteryStates: masteryStates.map {
                ExportedMasteryState(
                    knowledgeNodeID: $0.knowledgeNodeID,
                    vector: $0.vector,
                    confidence: $0.confidence,
                    stabilityDays: $0.stabilityDays,
                    lastEvidenceAt: $0.lastEvidenceAt,
                    lifetimeXP: $0.lifetimeXP
                )
            },
            evidence: evidenceRecords.map {
                ExportedEvidence(
                    id: $0.id,
                    knowledgeNodeID: $0.knowledgeNodeID,
                    kind: $0.kind,
                    timestamp: $0.timestamp,
                    summary: $0.summary,
                    rationale: $0.rationale,
                    isVerified: $0.isVerified
                )
            },
            sources: sources.filter { $0.path != "demo://" }.map {
                ExportedSource(id: $0.id, name: $0.name, kind: $0.kind, path: $0.path, isEnabled: $0.isEnabled, analyzeWorkingTree: $0.analyzeWorkingTree, authorFilter: $0.authorFilter)
            },
            endpoints: endpointProfiles.map {
                ExportedEndpoint(id: $0.id, name: $0.name, baseURLString: $0.baseURLString, selectedModelID: $0.selectedModelID, cachedModelIDs: $0.cachedModelIDs, isEnabled: $0.isEnabled)
            },
            challenges: challenges.map {
                ExportedChallenge(id: $0.id, title: $0.title, description: $0.challengeDescription, status: $0.status, rewardXP: $0.rewardXP)
            },
            digests: digests.map {
                ExportedDigest(date: $0.date, summary: $0.summary, xpEarned: $0.xpEarned)
            },
            reviewPlans: reviewPlans.map {
                ExportedReviewPlan(
                    id: $0.id,
                    knowledgeNodeID: $0.knowledgeNodeID,
                    createdAt: $0.createdAt,
                    scheduledAt: $0.scheduledAt,
                    reason: $0.reason,
                    status: $0.status
                )
            },
            activityTrackingExclusions: activityTrackingExclusions.map {
                ExportedActivityTrackingExclusion(
                    id: $0.id,
                    sourceID: $0.sourceID,
                    sourceKind: SourceKind(rawValue: $0.sourceKindRawValue) ?? .manual,
                    sourceLocator: $0.sourceLocator,
                    createdAt: $0.createdAt,
                    reason: $0.reason
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bundle)
    }

    func importJSON(_ data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(ExportBundle.self, from: data)
        try await clearAllData()
        for item in bundle.knowledgeNodes {
            modelContext.insert(
                KnowledgeNode(
                    id: item.id,
                    name: item.name,
                    domain: item.domain,
                    parentID: item.parentID,
                    isProvisional: item.isProvisional
                )
            )
        }
        for item in bundle.masteryStates {
            modelContext.insert(
                MasteryState(
                    knowledgeNodeID: item.knowledgeNodeID,
                    vector: item.vector,
                    confidence: item.confidence,
                    stabilityDays: item.stabilityDays,
                    lastEvidenceAt: item.lastEvidenceAt,
                    lifetimeXP: item.lifetimeXP,
                    highestStage: MasteryStage.stage(for: item.vector.composite)
                )
            )
        }
        for item in bundle.evidence {
            modelContext.insert(
                EvidenceRecord(
                    id: item.id,
                    activityID: UUID(),
                    knowledgeNodeID: item.knowledgeNodeID,
                    kind: item.kind,
                    timestamp: item.timestamp,
                    summary: item.summary,
                    rationale: item.rationale,
                    difficulty: 1,
                    independence: 1,
                    aiConfidence: 0.8,
                    isVerified: item.isVerified,
                    fingerprint: "import-\(item.id.uuidString)"
                )
            )
        }
        for item in bundle.sources {
            modelContext.insert(
                SourceConfiguration(
                    id: item.id,
                    name: item.name,
                    kind: item.kind,
                    path: item.path,
                    isEnabled: item.isEnabled,
                    analyzeWorkingTree: item.analyzeWorkingTree,
                    authorFilter: item.authorFilter ?? ""
                )
            )
        }
        for item in bundle.endpoints {
            let profile = AIEndpointProfile(
                id: item.id,
                name: item.name,
                baseURLString: item.baseURLString,
                selectedModelID: item.selectedModelID,
                isEnabled: item.isEnabled
            )
            profile.setCachedModelIDs(item.cachedModelIDs)
            modelContext.insert(profile)
        }
        for item in bundle.challenges {
            modelContext.insert(
                Challenge(
                    id: item.id,
                    title: item.title,
                    challengeDescription: item.description,
                    estimatedMinutes: 45,
                    knowledgeNodeIDs: [],
                    requirements: [],
                    rewardXP: item.rewardXP,
                    status: item.status
                )
            )
        }
        for item in bundle.digests {
            modelContext.insert(DailyDigest(date: item.date, summary: item.summary, xpEarned: item.xpEarned))
        }
        for item in bundle.reviewPlans ?? [] {
            modelContext.insert(
                ReviewPlan(
                    id: item.id,
                    knowledgeNodeID: item.knowledgeNodeID,
                    createdAt: item.createdAt,
                    scheduledAt: item.scheduledAt,
                    reason: item.reason,
                    status: item.status
                )
            )
        }
        for item in bundle.activityTrackingExclusions ?? [] {
            modelContext.insert(
                ActivityTrackingExclusion(
                    id: item.id,
                    sourceID: item.sourceID,
                    sourceKind: item.sourceKind,
                    sourceLocator: item.sourceLocator,
                    createdAt: item.createdAt,
                    reason: item.reason
                )
            )
        }
        try modelContext.save()
        load()
        selectedKnowledgeNodeID = knowledgeNodes.first?.id
    }

    func clearAllData() async throws {
        for endpoint in endpointProfiles { try await keychain.deleteAPIKey(endpointID: endpoint.id) }
        try modelContext.delete(model: AIEndpointProfile.self)
        try modelContext.delete(model: SourceConfiguration.self)
        try modelContext.delete(model: ActivityEvent.self)
        try modelContext.delete(model: ActivityTrackingExclusion.self)
        try modelContext.delete(model: EvidenceRecord.self)
        try modelContext.delete(model: KnowledgeNode.self)
        try modelContext.delete(model: KnowledgeEdge.self)
        try modelContext.delete(model: MasteryState.self)
        try modelContext.delete(model: ScoreLedgerEntry.self)
        try modelContext.delete(model: TaxonomySuggestion.self)
        try modelContext.delete(model: ReviewPlan.self)
        try modelContext.delete(model: Challenge.self)
        try modelContext.delete(model: DailyDigest.self)
        try modelContext.delete(model: AnalysisRun.self)
        try modelContext.save()
        setActiveEndpoint(nil)
        load()
    }

    private func resolvedAPIKey(draft: EndpointDraft) async throws -> String {
        if !draft.apiKey.isEmpty { return draft.apiKey }
        return try await keychain.apiKey(endpointID: draft.id) ?? ""
    }

    @discardableResult
    func apply(
        envelope: AnalysisEnvelope,
        to events: [ActivityEvent],
        analysisRun: AnalysisRun,
        createsAggregateResults: Bool = true
    ) throws -> Int {
        let eventByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        let suggestionByName = envelope.nodeSuggestions.reduce(into: [String: NodeSuggestion]()) { result, suggestion in
            let key = suggestion.proposedName.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            if result[key] == nil { result[key] = suggestion }
        }
        var xpEarned = 0
        for analyzed in envelope.evidence {
            guard let event = eventByID[analyzed.activityID] else { continue }
            let normalizedName = analyzed.knowledgeName.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            let nodeSuggestion = suggestionByName[normalizedName]
            let verifiedNode = verifiedExistingNode(for: analyzed)
            let resolution = resolveNode(for: analyzed, suggestedDomain: nodeSuggestion?.domain)
            let node = resolution.node
            let isVerified = verifiedNode?.id == node.id

            if resolution.isNew {
                let suggestion = TaxonomySuggestion(
                        suggestionType: "newNode",
                        proposedName: node.name,
                        relatedNodeID: node.id,
                        activityID: analyzed.activityID,
                        rationale: nodeSuggestion?.rationale ?? analyzed.rationale,
                        confidence: nodeSuggestion?.confidence ?? analyzed.confidence
                    )
                modelContext.insert(suggestion)
                taxonomySuggestions.insert(suggestion, at: 0)
            }
            let evidence = EvidenceRecord(
                activityID: analyzed.activityID,
                knowledgeNodeID: node.id,
                kind: analyzed.kind,
                timestamp: event.timestamp,
                summary: analyzed.summary,
                rationale: analyzed.rationale,
                difficulty: analyzed.difficulty,
                independence: analyzed.independence,
                aiConfidence: analyzed.confidence,
                isVerified: isVerified,
                fingerprint: event.fingerprint + "-" + node.id.uuidString
            )
            modelContext.insert(evidence)
            evidenceRecords.append(evidence)
            evidenceByID[evidence.id] = evidence
            evidenceByNodeID[node.id, default: []].insert(evidence, at: 0)
            if isVerified {
                xpEarned += applyScoring(evidence: evidence, node: node)
            } else {
                let suggestion = TaxonomySuggestion(
                        suggestionType: "reviewEvidence",
                        proposedName: analyzed.knowledgeName,
                        relatedNodeID: node.id,
                        activityID: analyzed.activityID,
                        evidenceID: evidence.id,
                        rationale: analyzed.rationale,
                        confidence: analyzed.matchConfidence
                    )
                modelContext.insert(suggestion)
                taxonomySuggestions.insert(suggestion, at: 0)
            }
        }

        events.forEach { $0.isProcessed = true }

        for edge in envelope.edgeSuggestions {
            guard let sourceNode = resolveNodeByName(edge.sourceName),
                  let targetNode = resolveNodeByName(edge.targetName),
                  sourceNode.id != targetNode.id else { continue }
            let exists = knowledgeEdges.contains {
                ($0.sourceNodeID == sourceNode.id && $0.targetNodeID == targetNode.id) ||
                ($0.sourceNodeID == targetNode.id && $0.targetNodeID == sourceNode.id && $0.relationRawValue == edge.relation)
            }
            if !exists {
                let newEdge = KnowledgeEdge(
                    sourceNodeID: sourceNode.id,
                    targetNodeID: targetNode.id,
                    relationRawValue: edge.relation,
                    confidence: edge.confidence
                )
                modelContext.insert(newEdge)
                knowledgeEdges.append(newEdge)
            }
        }

        if createsAggregateResults, let suggestion = envelope.challengeSuggestion {
            let challenge = Challenge(
                    title: suggestion.title,
                    challengeDescription: suggestion.description,
                    estimatedMinutes: suggestion.estimatedMinutes,
                    knowledgeNodeIDs: [],
                    requirements: suggestion.requirements,
                    rewardXP: suggestion.rewardXP
                )
            modelContext.insert(challenge)
            challenges.insert(challenge, at: 0)
        }
        if createsAggregateResults {
            let digest = DailyDigest(date: .now, summary: envelope.sessionSummary, xpEarned: xpEarned)
            modelContext.insert(digest)
            digests.insert(digest, at: 0)
        }
        return xpEarned
    }

    func clearAnalysisHistory() throws {
        try modelContext.delete(model: EvidenceRecord.self)
        try modelContext.delete(model: KnowledgeEdge.self)
        try modelContext.delete(model: MasteryState.self)
        try modelContext.delete(model: ScoreLedgerEntry.self)
        try modelContext.delete(model: TaxonomySuggestion.self)
        try modelContext.delete(model: ReviewPlan.self)
        try modelContext.delete(model: Challenge.self)
        try modelContext.delete(model: DailyDigest.self)
        try modelContext.delete(model: AnalysisRun.self)
        try modelContext.delete(model: KnowledgeNode.self)
        try modelContext.fetch(FetchDescriptor<ActivityEvent>()).forEach { $0.isProcessed = false }
        try modelContext.save()
        selectedKnowledgeNodeID = nil
        load()
        statusMessage = "已清除分析结果；原始活动、数据源和 AI 接口均已保留"
    }

    private func removeExistingAnalysis(for activityIDs: Set<UUID>) {
        let removedEvidence = evidenceRecords.filter { activityIDs.contains($0.activityID) }
        let removedEvidenceIDs = Set(removedEvidence.map(\.id))
        let affectedNodeIDs = Set(removedEvidence.map(\.knowledgeNodeID))

        scoreLedgerEntries
            .filter { removedEvidenceIDs.contains($0.evidenceID) || affectedNodeIDs.contains($0.knowledgeNodeID) }
            .forEach(modelContext.delete)
        taxonomySuggestions
            .filter { suggestion in suggestion.activityID.map(activityIDs.contains) == true }
            .forEach(modelContext.delete)
        removedEvidence.forEach(modelContext.delete)
        activityEvents.filter { activityIDs.contains($0.id) }.forEach { $0.isProcessed = false }

        let remainingEvidence = evidenceRecords.filter { !removedEvidenceIDs.contains($0.id) }
        var removedNodeIDs = Set<UUID>()
        for nodeID in affectedNodeIDs {
            let nodeEvidence = remainingEvidence.filter { $0.knowledgeNodeID == nodeID }
            if nodeEvidence.isEmpty,
               let node = knowledgeNodes.first(where: { $0.id == nodeID }),
               node.isProvisional {
                knowledgeEdges
                    .filter { $0.sourceNodeID == nodeID || $0.targetNodeID == nodeID }
                    .forEach(modelContext.delete)
                taxonomySuggestions
                    .filter { $0.relatedNodeID == nodeID }
                    .forEach(modelContext.delete)
                if let state = masteryStates.first(where: { $0.knowledgeNodeID == nodeID }) {
                    modelContext.delete(state)
                }
                modelContext.delete(node)
                removedNodeIDs.insert(nodeID)
            } else {
                replayMastery(nodeID: nodeID, evidence: nodeEvidence)
            }
        }

        evidenceRecords.removeAll { removedEvidenceIDs.contains($0.id) }
        scoreLedgerEntries.removeAll { affectedNodeIDs.contains($0.knowledgeNodeID) }
        taxonomySuggestions.removeAll { suggestion in
            suggestion.activityID.map(activityIDs.contains) == true ||
                suggestion.relatedNodeID.map(removedNodeIDs.contains) == true
        }
        knowledgeEdges.removeAll { removedNodeIDs.contains($0.sourceNodeID) || removedNodeIDs.contains($0.targetNodeID) }
        masteryStates.removeAll { removedNodeIDs.contains($0.knowledgeNodeID) }
        knowledgeNodes.removeAll { removedNodeIDs.contains($0.id) }
    }

    private func replayMastery(nodeID: UUID, evidence: [EvidenceRecord]) {
        let state = masteryStates.first(where: { $0.knowledgeNodeID == nodeID }) ?? {
            let state = MasteryState(knowledgeNodeID: nodeID)
            modelContext.insert(state)
            return state
        }()
        state.vector = .zero
        state.confidence = 0
        state.stabilityDays = 3
        state.lastEvidenceAt = nil
        state.lifetimeXP = 0
        state.highestStageRawValue = MasteryStage.entry.rawValue

        for item in evidence.filter(\.isVerified).sorted(by: { $0.timestamp < $1.timestamp }) {
            let result = scoringEngine.apply(
                ScoringInput(
                    current: state.vector,
                    kind: item.kind,
                    difficulty: item.difficulty,
                    independence: item.independence,
                    confidence: item.aiConfidence,
                    stabilityDays: state.stabilityDays,
                    lastEvidenceAt: state.lastEvidenceAt,
                    timestamp: item.timestamp
                )
            )
            state.vector = result.updated
            state.stabilityDays = result.stabilityDays
            state.lastEvidenceAt = item.timestamp
            state.lifetimeXP += result.xpAwarded
            state.highestStageRawValue = MasteryStage.stage(for: state.composite).rawValue
            modelContext.insert(
                ScoreLedgerEntry(
                    evidenceID: item.id,
                    knowledgeNodeID: nodeID,
                    timestamp: item.timestamp,
                    previousComposite: result.previousComposite,
                    newComposite: result.newComposite,
                    xpAwarded: result.xpAwarded,
                    reason: item.rationale
                )
            )
        }
        state.confidence = confidence(for: nodeID, evidence: evidence)
    }

    private func resolveNodeByName(_ name: String) -> KnowledgeNode? {
        knowledgeNodes.first(where: { $0.name.localizedStandardCompare(name) == .orderedSame })
    }

    func evidence(for suggestion: TaxonomySuggestion) -> EvidenceRecord? {
        guard let evidenceID = suggestion.evidenceID else { return nil }
        return evidenceByID[evidenceID]
    }

    func approveSuggestion(_ suggestion: TaxonomySuggestion) {
        guard suggestion.status == "pending" else { return }
        if suggestion.suggestionType == "reviewEvidence" {
            guard let unverified = evidence(for: suggestion),
                  !unverified.isVerified,
                  let node = node(for: unverified.knowledgeNodeID) else {
                statusMessage = "无法审核：该建议缺少明确的证据关联，请重新分析对应活动"
                return
            }
            unverified.isVerified = true
            let xp = applyScoring(evidence: unverified, node: node)
            statusMessage = "已批准证据并记入 \(xp) XP"
        } else if suggestion.suggestionType == "newNode" {
            if let nodeID = suggestion.relatedNodeID, let node = node(for: nodeID) {
                node.isProvisional = false
                statusMessage = "已收录知识点“\(node.name)”"
            }
        }
        suggestion.status = "approved"
        try? modelContext.save()
        refreshDerivedState()
    }

    func rejectSuggestion(_ suggestion: TaxonomySuggestion) {
        guard suggestion.status == "pending" else { return }
        if suggestion.suggestionType == "reviewEvidence" {
            guard let unverified = evidence(for: suggestion), !unverified.isVerified else {
                statusMessage = "无法忽略：该建议缺少明确的证据关联，请重新分析对应活动"
                return
            }
            modelContext.delete(unverified)
            evidenceRecords.removeAll { $0.id == unverified.id }
        } else if suggestion.suggestionType == "newNode" {
            if let nodeID = suggestion.relatedNodeID,
               let node = node(for: nodeID),
               !evidenceRecords.contains(where: { $0.knowledgeNodeID == nodeID && $0.isVerified }) {
                if let state = mastery(for: nodeID) {
                    modelContext.delete(state)
                    masteryStates.removeAll { $0.knowledgeNodeID == nodeID }
                }
                modelContext.delete(node)
                knowledgeNodes.removeAll { $0.id == nodeID }
            }
        }
        suggestion.status = "rejected"
        statusMessage = "已忽略该建议"
        try? modelContext.save()
        refreshDerivedState()
    }

    func mergeSuggestion(_ suggestion: TaxonomySuggestion, into targetNodeID: UUID) {
        guard suggestion.status == "pending", let targetNode = node(for: targetNodeID) else { return }
        if suggestion.suggestionType == "reviewEvidence" {
            guard let unverified = evidence(for: suggestion), !unverified.isVerified else {
                statusMessage = "无法合并：该建议缺少明确的证据关联，请重新分析对应活动"
                return
            }
            unverified.knowledgeNodeID = targetNodeID
            unverified.isVerified = true
            let xp = applyScoring(evidence: unverified, node: targetNode)
            statusMessage = "已将证据合并至“\(targetNode.name)”，记入 \(xp) XP"
        } else if suggestion.suggestionType == "newNode" {
            if let oldNodeID = suggestion.relatedNodeID {
                let relatedEvidence = evidenceRecords.filter { $0.knowledgeNodeID == oldNodeID }
                for ev in relatedEvidence {
                    ev.knowledgeNodeID = targetNodeID
                    if ev.isVerified {
                        _ = applyScoring(evidence: ev, node: targetNode)
                    }
                }
                if let oldNode = node(for: oldNodeID) {
                    if let state = mastery(for: oldNodeID) {
                        modelContext.delete(state)
                        masteryStates.removeAll { $0.knowledgeNodeID == oldNodeID }
                    }
                    modelContext.delete(oldNode)
                    knowledgeNodes.removeAll { $0.id == oldNodeID }
                }
                statusMessage = "已将“\(suggestion.proposedName)”合并至“\(targetNode.name)”"
            }
        }
        suggestion.status = "merged"
        try? modelContext.save()
        refreshDerivedState()
    }

    func approveAllPendingSuggestions() {
        let pending = taxonomySuggestions.filter { $0.status == "pending" }
        guard !pending.isEmpty else { return }
        var approvedCount = 0
        for suggestion in pending {
            if suggestion.suggestionType == "reviewEvidence" {
                guard let unverified = evidence(for: suggestion),
                      !unverified.isVerified,
                      let node = node(for: unverified.knowledgeNodeID) else { continue }
                unverified.isVerified = true
                _ = applyScoring(evidence: unverified, node: node)
            } else if suggestion.suggestionType == "newNode" {
                if let nodeID = suggestion.relatedNodeID, let node = node(for: nodeID) {
                    node.isProvisional = false
                }
            }
            suggestion.status = "approved"
            approvedCount += 1
        }
        statusMessage = approvedCount == pending.count
            ? "已批量确认 \(approvedCount) 条待审核建议"
            : "已确认 \(approvedCount) 条；另有 \(pending.count - approvedCount) 条缺少明确证据关联"
        try? modelContext.save()
        refreshDerivedState()
    }

    func updateChallengeStatus(_ challenge: Challenge, status: String) {
        guard status != "completed" else {
            statusMessage = "挑战完成必须由后续真实学习证据验证，不能手动结算"
            return
        }
        challenge.status = status
        if status == "in_progress" {
            statusMessage = "已接取挑战“\(challenge.title)”，开始实践吧！"
        } else {
            statusMessage = "已更新挑战状态"
        }
        try? modelContext.save()
    }

    private func verifiedExistingNode(for analyzed: AnalyzedEvidence) -> KnowledgeNode? {
        if analyzed.matchConfidence >= 0.85,
           let matchedNodeID = analyzed.matchedNodeID,
           let matched = knowledgeNodes.first(where: { $0.id == matchedNodeID && !$0.isProvisional }) {
            return matched
        }
        return nil
    }

    private func resolveNode(for analyzed: AnalyzedEvidence, suggestedDomain: String?) -> (node: KnowledgeNode, isNew: Bool) {
        if let matchedNodeID = analyzed.matchedNodeID,
           let matched = knowledgeNodes.first(where: { $0.id == matchedNodeID }) {
            return (matched, false)
        }
        if let named = knowledgeNodes.first(where: { $0.name.localizedStandardCompare(analyzed.knowledgeName) == .orderedSame }) {
            return (named, false)
        }
        let proposedDomain = suggestedDomain?.trimmingCharacters(in: .whitespacesAndNewlines)
        let domain = proposedDomain.flatMap { $0.isEmpty ? nil : $0 } ?? "待分类"
        let node = KnowledgeNode(
            name: analyzed.knowledgeName,
            domain: domain,
            isProvisional: true
        )
        modelContext.insert(node)
        let state = MasteryState(knowledgeNodeID: node.id)
        modelContext.insert(state)
        knowledgeNodes.append(node)
        masteryStates.append(state)
        nodeByID[node.id] = node
        masteryByNodeID[node.id] = state
        return (node, true)
    }

    private func applyScoring(evidence: EvidenceRecord, node: KnowledgeNode) -> Int {
        let state = masteryByNodeID[node.id] ?? {
            let created = MasteryState(knowledgeNodeID: node.id)
            modelContext.insert(created)
            masteryStates.append(created)
            masteryByNodeID[node.id] = created
            return created
        }()
        let result = scoringEngine.apply(
            ScoringInput(
                current: state.vector,
                kind: evidence.kind,
                difficulty: evidence.difficulty,
                independence: evidence.independence,
                confidence: evidence.aiConfidence,
                stabilityDays: state.stabilityDays,
                lastEvidenceAt: state.lastEvidenceAt,
                timestamp: evidence.timestamp
            )
        )
        state.vector = result.updated
        state.stabilityDays = result.stabilityDays
        state.lastEvidenceAt = evidence.timestamp
        state.lifetimeXP += result.xpAwarded
        state.confidence = confidence(for: node.id)
        if result.stage.level > (MasteryStage(rawValue: state.highestStageRawValue)?.level ?? 1) {
            state.highestStageRawValue = result.stage.rawValue
        }
        let ledgerEntry = ScoreLedgerEntry(
                evidenceID: evidence.id,
                knowledgeNodeID: node.id,
                timestamp: evidence.timestamp,
                previousComposite: result.previousComposite,
                newComposite: result.newComposite,
                xpAwarded: result.xpAwarded,
                reason: evidence.rationale
            )
        modelContext.insert(ledgerEntry)
        scoreLedgerEntries.insert(ledgerEntry, at: 0)
        ledgerByNodeID[node.id, default: []].append(ledgerEntry)
        ledgerByNodeID[node.id]?.sort { $0.timestamp < $1.timestamp }
        return result.xpAwarded
    }

    private func confidence(for nodeID: UUID) -> Double {
        confidence(for: nodeID, evidence: evidenceRecords)
    }

    private func confidence(for nodeID: UUID, evidence: [EvidenceRecord]) -> Double {
        let evidence = evidence.filter { $0.knowledgeNodeID == nodeID && $0.isVerified }
        let weighted = evidence.reduce(0.0) { result, item in
            let ageDays = max(0, Date.now.timeIntervalSince(item.timestamp) / 86_400)
            return result + item.aiConfidence * exp(-ageDays / 90)
        }
        return 100 * (1 - exp(-weighted / 6))
    }

    private func updateSnapshots() {
        domainProgress = analyticsEngine.computeDomainProgress(
            nodes: knowledgeNodes,
            masteryStates: masteryStates,
            scoringEngine: scoringEngine
        )
        todayMasteryChanges = analyticsEngine.computeTodayMasteryChanges(nodes: knowledgeNodes, ledgerEntries: scoreLedgerEntries)
        todayXPGains = analyticsEngine.computeTodayXPGains(evidenceRecords: evidenceRecords, ledgerEntries: scoreLedgerEntries)
        forgettingProjections = analyticsEngine.computeForgettingProjections(nodes: knowledgeNodes, masteryStates: masteryStates, scoringEngine: scoringEngine)
    }

    private func refreshDerivedState() {
        rebuildIndexes()
        refreshActivityCounts()
        updateSnapshots()
    }

    private func load() {
        do {
            endpointProfiles = try modelContext.fetch(FetchDescriptor<AIEndpointProfile>(sortBy: [SortDescriptor(\.name)]))
            sources = try modelContext.fetch(FetchDescriptor<SourceConfiguration>(sortBy: [SortDescriptor(\.name)]))
            activityTrackingExclusions = try modelContext.fetch(
                FetchDescriptor<ActivityTrackingExclusion>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            )
            var recentActivityDescriptor = FetchDescriptor<ActivityEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            recentActivityDescriptor.fetchLimit = 200
            activityEvents = try modelContext.fetch(recentActivityDescriptor)
            evidenceRecords = try modelContext.fetch(FetchDescriptor<EvidenceRecord>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)]))
            knowledgeNodes = try modelContext.fetch(FetchDescriptor<KnowledgeNode>(sortBy: [SortDescriptor(\.name)]))
            masteryStates = try modelContext.fetch(FetchDescriptor<MasteryState>())
            knowledgeEdges = try modelContext.fetch(FetchDescriptor<KnowledgeEdge>())
            scoreLedgerEntries = try modelContext.fetch(FetchDescriptor<ScoreLedgerEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)]))
            challenges = try modelContext.fetch(FetchDescriptor<Challenge>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            digests = try modelContext.fetch(FetchDescriptor<DailyDigest>(sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]))
            taxonomySuggestions = try modelContext.fetch(FetchDescriptor<TaxonomySuggestion>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            reviewPlans = try modelContext.fetch(FetchDescriptor<ReviewPlan>(sortBy: [SortDescriptor(\.scheduledAt)]))
            refreshActivityCounts()
            rebuildIndexes()
            reconcileActiveEndpointSelection()
            updateSnapshots()
        } catch {
            statusMessage = "读取本地数据失败：\(error.localizedDescription)"
        }
    }

    private func fetchActivities(ids: Set<UUID>?) throws -> [ActivityEvent] {
        if let ids {
            var result: [ActivityEvent] = []
            result.reserveCapacity(ids.count)
            for id in ids {
                var descriptor = FetchDescriptor<ActivityEvent>(predicate: #Predicate { $0.id == id })
                descriptor.fetchLimit = 1
                if let event = try modelContext.fetch(descriptor).first {
                    result.append(event)
                }
            }
            return result.sorted { $0.timestamp < $1.timestamp }
        }
        return try modelContext.fetch(
            FetchDescriptor(
                predicate: #Predicate<ActivityEvent> { !$0.isProcessed },
                sortBy: [SortDescriptor(\.timestamp)]
            )
        )
    }

    private func createTrackingExclusion(for activity: ActivityEvent, reason: String) {
        let key = trackingKey(sourceID: activity.sourceID, sourceLocator: activity.sourceLocator)
        guard !activityTrackingExclusions.contains(where: { trackingKey($0) == key }) else { return }
        let exclusion = ActivityTrackingExclusion(
            sourceID: activity.sourceID,
            sourceKind: SourceKind(rawValue: activity.sourceKindRawValue) ?? .manual,
            sourceLocator: activity.sourceLocator,
            reason: reason
        )
        modelContext.insert(exclusion)
        activityTrackingExclusions.insert(exclusion, at: 0)
    }

    private func trackingKey(_ exclusion: ActivityTrackingExclusion) -> String {
        trackingKey(sourceID: exclusion.sourceID, sourceLocator: exclusion.sourceLocator)
    }

    private func trackingKey(sourceID: UUID, sourceLocator: String) -> String {
        sourceID.uuidString + "\u{001F}" + sourceLocator
    }

    private func scheduleStatusMessageDismissal() {
        statusMessageDismissalTask?.cancel()
        guard let message = statusMessage else {
            statusMessageDismissalTask = nil
            return
        }

        let delay = Self.isErrorStatusMessage(message)
            ? statusMessageErrorDuration
            : statusMessageSuccessDuration
        statusMessageDismissalTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self, self.statusMessage == message else { return }
            self.statusMessage = nil
        }
    }

    private nonisolated static func isErrorStatusMessage(_ message: String) -> Bool {
        ["失败", "错误", "无法", "缺少"].contains { message.localizedStandardContains($0) }
    }

    private func refreshActivityCounts() {
        do {
            totalActivityCount = try modelContext.fetchCount(FetchDescriptor<ActivityEvent>())
            pendingActivityCount = try modelContext.fetchCount(
                FetchDescriptor(predicate: #Predicate<ActivityEvent> { !$0.isProcessed })
            )
        } catch {
            AppLogger.app.error("Failed to count activities: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func rebuildIndexes() {
        nodeByID = Dictionary(uniqueKeysWithValues: knowledgeNodes.map { ($0.id, $0) })
        masteryByNodeID = Dictionary(uniqueKeysWithValues: masteryStates.map { ($0.knowledgeNodeID, $0) })
        evidenceByID = Dictionary(uniqueKeysWithValues: evidenceRecords.map { ($0.id, $0) })
        evidenceByNodeID = Dictionary(grouping: evidenceRecords, by: \.knowledgeNodeID)
        ledgerByNodeID = Dictionary(grouping: scoreLedgerEntries, by: \.knowledgeNodeID)
            .mapValues { $0.sorted { $0.timestamp < $1.timestamp } }
    }

    private func reconcileActiveEndpointSelection() {
        if let activeEndpointID,
           endpointProfiles.contains(where: { $0.id == activeEndpointID && $0.isEnabled }) {
            return
        }
        let fallback = endpointProfiles.first(where: { $0.isEnabled && !$0.selectedModelID.isEmpty })
            ?? endpointProfiles.first(where: \.isEnabled)
        setActiveEndpoint(fallback?.id)
    }

    private func icon(for kind: EvidenceKind) -> String {
        switch kind {
        case .exposure: "eye"
        case .explanation: "book"
        case .exercise: "checklist"
        case .project: "chevron.left.forwardslash.chevron.right"
        case .review: "arrow.clockwise"
        case .independentSolve: "target"
        }
    }

    private func cleanupLegacyDemoDataIfNeeded() {
        let migrationKey = "didRemoveBundledDemoData.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey),
              sources.contains(where: { $0.path == "demo://" }) else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let demoNodeNames: Set<String> = [
            "React 状态模型", "Hooks", "不可变更新", "派生状态",
            "Reducer", "调试", "JavaScript 闭包", "事务隔离级别"
        ]
        let demoNodes = knowledgeNodes.filter { demoNodeNames.contains($0.name) }
        let demoNodeIDs = Set(demoNodes.map(\.id))
        sources.filter { $0.path == "demo://" }.forEach(modelContext.delete)
        activityEvents.filter { $0.fingerprint.hasPrefix("demo-") || $0.sourceLocator.hasPrefix("demo://") }.forEach(modelContext.delete)
        evidenceRecords.filter { $0.fingerprint.hasPrefix("demo-evidence-") }.forEach(modelContext.delete)
        masteryStates.filter { demoNodeIDs.contains($0.knowledgeNodeID) }.forEach(modelContext.delete)
        knowledgeEdges.filter { demoNodeIDs.contains($0.sourceNodeID) || demoNodeIDs.contains($0.targetNodeID) }.forEach(modelContext.delete)
        scoreLedgerEntries.filter { demoNodeIDs.contains($0.knowledgeNodeID) }.forEach(modelContext.delete)
        demoNodes.forEach(modelContext.delete)
        challenges.filter { $0.title == "重构任务面板的状态层" }.forEach(modelContext.delete)
        digests.filter { $0.summary.hasPrefix("你把 React 状态模型") }.forEach(modelContext.delete)
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    private func cleanupUnverifiedChallengeCompletionIfNeeded() {
        let migrationKey = "didResetUnverifiedChallengeCompletions.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        challenges.filter { $0.status == "completed" }.forEach { $0.status = "in_progress" }
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - 精准打开设置 Tab
    @MainActor
    func openSettings(section: SettingsSection = .general) {
        self.selectedSettingsSection = section
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil as Any?, from: nil as Any?)
        NSApp.activate(ignoringOtherApps: true)
    }
}
