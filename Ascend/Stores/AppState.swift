import AppKit
import Foundation
import Observation
import SwiftData
import UserNotifications

@MainActor
@Observable
final class AppState {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    var selectedSection: NavigationSection = .today
    var isCollecting = true {
        didSet {
            automationDefaults.set(isCollecting, forKey: AutomationPreferences.collectionEnabledKey)
            restartCollectionSchedulerIfNeeded()
            syncLocalMarkdownWatchers()
        }
    }
    var collectionIntervalMinutes = AutomationPreferences.defaultCollectionIntervalMinutes {
        didSet {
            automationDefaults.set(collectionIntervalMinutes, forKey: AutomationPreferences.collectionIntervalMinutesKey)
            restartCollectionSchedulerIfNeeded()
        }
    }
    var automaticAnalysisPolicy = AutomaticAnalysisPolicy.off {
        didSet { automationDefaults.set(automaticAnalysisPolicy.rawValue, forKey: AutomationPreferences.analysisPolicyKey) }
    }
    var automaticAnalysisThreshold = AutomationPreferences.defaultAnalysisThreshold {
        didSet {
            automationDefaults.set(automaticAnalysisThreshold, forKey: AutomationPreferences.analysisThresholdKey)
        }
    }
    var automaticDailyAnalysisHour = AutomationPreferences.defaultDailyAnalysisHour {
        didSet {
            automationDefaults.set(automaticDailyAnalysisHour, forKey: AutomationPreferences.dailyAnalysisHourKey)
        }
    }
    var automaticDailyAnalysisMinute = AutomationPreferences.defaultDailyAnalysisMinute {
        didSet {
            automationDefaults.set(automaticDailyAnalysisMinute, forKey: AutomationPreferences.dailyAnalysisMinuteKey)
        }
    }
    var isCollectionSchedulerRunning = false
    var isScanningSources = false
    var isAnalyzing = false
    var analysisProgressMessage: String?
    var statusMessage: String? {
        didSet { scheduleStatusMessageDismissal() }
    }
    var endpointProfiles: [AIEndpointProfile] = []
    var sources: [SourceConfiguration] = []
    var activityTrackingExclusions: [ActivityTrackingExclusion] = []
    var activityEvents: [ActivityEvent] = []
    var activityFeedEvents: [ActivityEvent] = []
    var activityFeedTotalCount = 0
    var totalActivityCount = 0
    var pendingActivityCount = 0
    var todayActivityCount = 0
    var evidenceRecords: [EvidenceRecord] = []
    var knowledgeNodes: [KnowledgeNode] = []
    var masteryStates: [MasteryState] = []
    var knowledgeEdges: [KnowledgeEdge] = []
    var scoreLedgerEntries: [ScoreLedgerEntry] = []
    var challenges: [Challenge] = []
    var digests: [DailyDigest] = []
    var taxonomySuggestions: [TaxonomySuggestion] = []
    var reviewPlans: [ReviewPlan] = []
    var memoryStates: [MemoryState] = []
    var memoryReviewEvents: [MemoryReviewEvent] = []
    var challengeAutomationStates: [ChallengeAutomationState] = []
    var realmAdvancementEvents: [RealmAdvancementEvent] = []
    var automationReceipts: [AutomationReceipt] = []
    var activeEndpointID: UUID?
    var selectedKnowledgeNodeID: UUID?
    var selectedSettingsSection: SettingsSection = .general

    var domainProgress: [DomainProgressSnapshot] = []
    var todayMasteryChanges: [DashboardMetric] = []
    var todayXPGains: [XPGainItem] = []
    var forgettingProjections: [ForgettingProjection] = []
    var learningRecommendations: [LearningRecommendation] = []

    @ObservationIgnored let aiClient: any AIProviderClient
    @ObservationIgnored let keychain: KeychainStore
    @ObservationIgnored let scoringEngine: ScoringEngine
    @ObservationIgnored let memoryScheduler: any MemoryScheduling
    @ObservationIgnored let recommendationEngine: LearningRecommendationEngine
    @ObservationIgnored let topologyEngine: LearningTopologyEngine
    @ObservationIgnored let analyticsEngine: AnalyticsEngine
    @ObservationIgnored let gitConnector: GitActivityConnector
    @ObservationIgnored let markdownConnector: MarkdownActivityConnector
    @ObservationIgnored let remoteGitRepositoryConnector: RemoteGitRepositoryConnector
    @ObservationIgnored let markdownSnapshotStore: MarkdownSnapshotStore
    @ObservationIgnored let markdownDebouncer: MarkdownEventDebouncer
    @ObservationIgnored var localMarkdownWatchers: [UUID: LocalMarkdownEventSource] = [:]
    @ObservationIgnored let digestScheduler: DigestScheduler
    @ObservationIgnored let notificationDeliveryPolicy: NotificationDeliveryPolicy
    @ObservationIgnored var lastReviewNotificationDeliveredAt: Date?
    @ObservationIgnored var isNotificationDeliveryInFlight = false
    @ObservationIgnored let collectionScheduler: ActivityCollectionScheduler
    @ObservationIgnored let automationTickScheduler: AutomationTickScheduler
    @ObservationIgnored let analysisScheduler: AnalysisScheduler
    @ObservationIgnored let triggerEngine: TriggerEngine
    @ObservationIgnored let challengeEvaluator: ChallengeEvaluator
    @ObservationIgnored let digestAggregator: DailyDigestAggregator
    @ObservationIgnored let automationDefaults: UserDefaults
    @ObservationIgnored let statusMessageSuccessDuration: Duration
    @ObservationIgnored let statusMessageErrorDuration: Duration
    @ObservationIgnored var nodeByID: [UUID: KnowledgeNode] = [:]
    @ObservationIgnored var masteryByNodeID: [UUID: MasteryState] = [:]
    @ObservationIgnored var memoryByNodeID: [UUID: MemoryState] = [:]
    @ObservationIgnored var evidenceByID: [UUID: EvidenceRecord] = [:]
    @ObservationIgnored var evidenceByNodeID: [UUID: [EvidenceRecord]] = [:]
    @ObservationIgnored var ledgerByNodeID: [UUID: [ScoreLedgerEntry]] = [:]
    @ObservationIgnored var statusMessageDismissalTask: Task<Void, Never>?
    @ObservationIgnored var automationStarted = false

    init(
        modelContainer: ModelContainer,
        aiClient: any AIProviderClient = OpenAICompatibleClient(),
        keychain: KeychainStore = .shared,
        scoringEngine: ScoringEngine = ScoringEngine(),
        memoryScheduler: any MemoryScheduling = FSRSMemoryScheduler(),
        recommendationEngine: LearningRecommendationEngine = LearningRecommendationEngine(),
        topologyEngine: LearningTopologyEngine = LearningTopologyEngine(),
        analyticsEngine: AnalyticsEngine = AnalyticsEngine(),
        gitConnector: GitActivityConnector = GitActivityConnector(),
        markdownConnector: MarkdownActivityConnector? = nil,
        remoteGitRepositoryConnector: RemoteGitRepositoryConnector = RemoteGitRepositoryConnector(),
        markdownSnapshotStore: MarkdownSnapshotStore = MarkdownSnapshotStore(),
        markdownDebouncer: MarkdownEventDebouncer = MarkdownEventDebouncer(),
        digestScheduler: DigestScheduler = DigestScheduler(),
        notificationDeliveryPolicy: NotificationDeliveryPolicy = NotificationDeliveryPolicy(),
        collectionScheduler: ActivityCollectionScheduler = ActivityCollectionScheduler(),
        automationTickScheduler: AutomationTickScheduler = AutomationTickScheduler(),
        analysisScheduler: AnalysisScheduler = AnalysisScheduler(),
        triggerEngine: TriggerEngine = TriggerEngine(),
        challengeEvaluator: ChallengeEvaluator = ChallengeEvaluator(),
        digestAggregator: DailyDigestAggregator = DailyDigestAggregator(),
        automationDefaults: UserDefaults = .standard,
        statusMessageSuccessDuration: Duration = .seconds(5),
        statusMessageErrorDuration: Duration = .seconds(10)
    ) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
        self.aiClient = aiClient
        self.keychain = keychain
        self.scoringEngine = scoringEngine
        self.memoryScheduler = memoryScheduler
        self.recommendationEngine = recommendationEngine
        self.topologyEngine = topologyEngine
        self.analyticsEngine = analyticsEngine
        self.gitConnector = gitConnector
        let snapshotStore = markdownSnapshotStore
        self.markdownSnapshotStore = snapshotStore
        self.markdownConnector = markdownConnector ?? MarkdownActivityConnector(snapshotStore: snapshotStore)
        self.remoteGitRepositoryConnector = remoteGitRepositoryConnector
        self.markdownDebouncer = markdownDebouncer
        self.digestScheduler = digestScheduler
        self.notificationDeliveryPolicy = notificationDeliveryPolicy
        self.collectionScheduler = collectionScheduler
        self.automationTickScheduler = automationTickScheduler
        self.analysisScheduler = analysisScheduler
        self.triggerEngine = triggerEngine
        self.challengeEvaluator = challengeEvaluator
        self.digestAggregator = digestAggregator
        self.automationDefaults = automationDefaults
        self.statusMessageSuccessDuration = statusMessageSuccessDuration
        self.statusMessageErrorDuration = statusMessageErrorDuration
        let automationPreferences = AutomationPreferences.current(defaults: automationDefaults)
        let notificationPreferences = NotificationPreferences(userDefaults: automationDefaults)
        self.lastReviewNotificationDeliveredAt = notificationPreferences.lastReviewDeliveredAt
        self.isCollecting = automationPreferences.collectionEnabled
        self.collectionIntervalMinutes = automationPreferences.collectionIntervalMinutes
        self.automaticAnalysisPolicy = automationPreferences.analysisPolicy
        self.automaticAnalysisThreshold = automationPreferences.analysisThreshold
        self.automaticDailyAnalysisHour = automationPreferences.dailyAnalysisHour
        self.automaticDailyAnalysisMinute = automationPreferences.dailyAnalysisMinute
        if let storedID = UserDefaults.standard.string(forKey: "activeEndpointID") {
            activeEndpointID = UUID(uuidString: storedID)
        }
        load()
        migrateLegacyRemoteGitSourcesIfNeeded()
        cleanupLegacyDemoDataIfNeeded()
        cleanupUnverifiedChallengeCompletionIfNeeded()
        cleanupDuplicateActivityEventsIfNeeded()
        load()
        selectedKnowledgeNodeID = nil
    }

    var activeEndpoint: AIEndpointProfile? {
        endpointProfiles.first { $0.id == activeEndpointID }
    }

    var presentedStatusMessage: String? {
        analysisProgressMessage ?? statusMessage
    }

    var totalXP: Int {
        masteryStates.reduce(0) { $0 + $1.lifetimeXP }
    }

    var challengeXP: Int {
        challenges.filter { $0.status == "completed" }.reduce(0) { $0 + $1.rewardXP }
    }

    var dueReviewCount: Int {
        reviewPlans.count { $0.status == "due" }
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

    func memory(for nodeID: UUID) -> MemoryState? {
        memoryByNodeID[nodeID]
    }

    func currentRetention(for nodeID: UUID, now: Date = .now) -> Double? {
        guard let memory = memory(for: nodeID), memory.reps > 0 else { return nil }
        do {
            return try memoryScheduler.retrievability(
                state: memory.schedulingState,
                at: now,
                desiredRetention: MemorySchedulingPreferences.desiredRetention
            ) * 100
        } catch {
            AppLogger.scoring.error("FSRS retrievability failed: \(error.localizedDescription, privacy: .public)")
            return memory.retrievability * 100
        }
    }

    func readiness(for nodeID: UUID, now: Date = .now) -> MasteryReadinessSnapshot? {
        guard let state = mastery(for: nodeID) else { return nil }
        var current = state.vector
        current.retention = currentRetention(for: nodeID, now: now) ?? state.retention
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
            syncLocalMarkdownWatchers()
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    func dismissStatusMessage() {
        statusMessage = nil
    }

    func refreshDerivedState() {
        rebuildIndexes()
        refreshActivityCounts()
        updateSnapshots()
    }

    func load() {
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
            challengeAutomationStates = try modelContext.fetch(FetchDescriptor<ChallengeAutomationState>())
            realmAdvancementEvents = try modelContext.fetch(
                FetchDescriptor<RealmAdvancementEvent>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
            )
            automationReceipts = try modelContext.fetch(FetchDescriptor<AutomationReceipt>())
            digests = try modelContext.fetch(FetchDescriptor<DailyDigest>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
            taxonomySuggestions = try modelContext.fetch(FetchDescriptor<TaxonomySuggestion>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            reviewPlans = try modelContext.fetch(FetchDescriptor<ReviewPlan>(sortBy: [SortDescriptor(\.scheduledAt)]))
            memoryStates = try modelContext.fetch(FetchDescriptor<MemoryState>())
            memoryReviewEvents = try modelContext.fetch(
                FetchDescriptor<MemoryReviewEvent>(sortBy: [SortDescriptor(\.reviewedAt)])
            )
            refreshActivityCounts()
            rebuildIndexes()
            reconcileActiveEndpointSelection()
            updateSnapshots()
            syncLocalMarkdownWatchers()
        } catch {
            statusMessage = "读取本地数据失败：\(error.localizedDescription)"
        }
    }

    // 优化：消除循环 N+1 fetch 查询
    func fetchActivities(ids: Set<UUID>?) throws -> [ActivityEvent] {
        if let ids {
            guard !ids.isEmpty else { return [] }
            var found: [UUID: ActivityEvent] = [:]
            for event in activityEvents where ids.contains(event.id) {
                found[event.id] = event
            }
            let missingIDs = ids.subtracting(found.keys)
            if !missingIDs.isEmpty {
                let allEvents = try modelContext.fetch(FetchDescriptor<ActivityEvent>())
                for event in allEvents where missingIDs.contains(event.id) {
                    found[event.id] = event
                }
            }
            return found.values.sorted { $0.timestamp < $1.timestamp }
        }
        return try modelContext.fetch(
            FetchDescriptor(
                predicate: #Predicate<ActivityEvent> { !$0.isProcessed },
                sortBy: [SortDescriptor(\.timestamp)]
            )
        )
    }

    func scheduleStatusMessageDismissal() {
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

    nonisolated static func isErrorStatusMessage(_ message: String) -> Bool {
        ["失败", "错误", "无法", "缺少"].contains { message.localizedStandardContains($0) }
    }

    func refreshActivityCounts() {
        do {
            totalActivityCount = try modelContext.fetchCount(FetchDescriptor<ActivityEvent>())
            pendingActivityCount = try modelContext.fetchCount(
                FetchDescriptor(predicate: #Predicate<ActivityEvent> { !$0.isProcessed })
            )
            let startOfToday = Calendar.current.startOfDay(for: .now)
            let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? .distantFuture
            todayActivityCount = try modelContext.fetchCount(
                FetchDescriptor(
                    predicate: #Predicate<ActivityEvent> {
                        $0.timestamp >= startOfToday && $0.timestamp < startOfTomorrow
                    }
                )
            )
        } catch {
            AppLogger.app.error("Failed to count activities: \(error.localizedDescription, privacy: .public)")
        }
    }

    func rebuildIndexes() {
        nodeByID = Dictionary(uniqueKeysWithValues: knowledgeNodes.map { ($0.id, $0) })
        masteryByNodeID = Dictionary(uniqueKeysWithValues: masteryStates.map { ($0.knowledgeNodeID, $0) })
        memoryByNodeID = Dictionary(uniqueKeysWithValues: memoryStates.map { ($0.knowledgeNodeID, $0) })
        evidenceByID = Dictionary(uniqueKeysWithValues: evidenceRecords.map { ($0.id, $0) })
        evidenceByNodeID = Dictionary(grouping: evidenceRecords, by: \.knowledgeNodeID)
        ledgerByNodeID = Dictionary(grouping: scoreLedgerEntries, by: \.knowledgeNodeID)
            .mapValues { $0.sorted { $0.timestamp < $1.timestamp } }
    }

    func currentComposite(for nodeID: UUID, now: Date = .now) -> Double {
        readiness(for: nodeID, now: now)?.currentComposite ?? 0
    }

    func currentCompositeByNodeID(now: Date = .now) -> [UUID: Double] {
        Dictionary(uniqueKeysWithValues: knowledgeNodes.map { ($0.id, currentComposite(for: $0.id, now: now)) })
    }

    // MARK: - 拓扑状态与先导查询

    func topologyStatus(for nodeID: UUID, now: Date = .now) -> NodeTopologyStatus {
        let compositeScores = currentCompositeByNodeID(now: now)
        return topologyEngine.status(for: nodeID, edges: knowledgeEdges, masteryByNodeID: compositeScores)
    }

    func prerequisites(for nodeID: UUID) -> [KnowledgeNode] {
        let prereqIDs = topologyEngine.prerequisiteNodeIDs(for: nodeID, in: knowledgeEdges)
        return prereqIDs.compactMap { nodeByID[$0] }
    }

    func unlockedNextConcepts(for nodeID: UUID, now: Date = .now) -> [KnowledgeNode] {
        let compositeScores = currentCompositeByNodeID(now: now)
        let unlockedIDs = topologyEngine.unlockedNextConcepts(for: nodeID, edges: knowledgeEdges, masteryByNodeID: compositeScores)
        return unlockedIDs.compactMap { nodeByID[$0] }
    }

    func downstreamConcepts(for nodeID: UUID) -> [KnowledgeNode] {
        let downstreamIDs = topologyEngine.downstreamNodeIDs(for: nodeID, in: knowledgeEdges)
        return downstreamIDs.compactMap { nodeByID[$0] }
    }

    func ancestorPrerequisites(for nodeID: UUID) -> [KnowledgeNode] {
        let ancestorIDs = topologyEngine.ancestorPrerequisiteIDs(for: nodeID, in: knowledgeEdges)
        return ancestorIDs.compactMap { nodeByID[$0] }
    }

    func lineageHighlightSet(for nodeID: UUID) -> Set<UUID> {
        topologyEngine.lineageHighlightSet(for: nodeID, in: knowledgeEdges)
    }

    // MARK: - 精准打开设置 Tab
    func openSettings(section: SettingsSection = .general) {
        self.selectedSettingsSection = section
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil as Any?, from: nil as Any?)
        NSApp.activate(ignoringOtherApps: true)
    }
}
