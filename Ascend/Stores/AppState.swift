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
    var automaticAssessmentPreparationEnabled = false {
        didSet {
            automationDefaults.set(
                automaticAssessmentPreparationEnabled,
                forKey: AutomationPreferences.assessmentPreparationEnabledKey
            )
        }
    }
    var isCollectionSchedulerRunning = false
    var isScanningSources = false
    /// 新增远程仓库后的首次同步状态；仅用于界面反馈，不持久化。
    var initialRemoteSyncingSourceIDs: Set<UUID> = []
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
    var activityFeedRevision = 0
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
    var assessmentSessions: [AssessmentSession] = []
    var assessmentItems: [AssessmentItem] = []
    var assessmentResponses: [AssessmentResponse] = []
    var masteryObservations: [MasteryObservation] = []
    var masteryEstimates: [MasteryEstimate] = []
    var performanceReceipts: [PerformanceReceipt] = []
    var challengeAutomationStates: [ChallengeAutomationState] = []
    var realmAdvancementEvents: [RealmAdvancementEvent] = []
    var automationReceipts: [AutomationReceipt] = []
    var dailyTasks: [DailyTask] = []
    var dailyTaskLogs: [DailyTaskLog] = []
    var focusSessions: [FocusSession] = []
    var activeEndpointID: UUID?
    var selectedKnowledgeNodeID: UUID?
    var selectedSettingsSection: SettingsSection = .general
    var isGeneratingAssessment = false
    var assessmentPreparationMessage: String?
    var requestedAssessmentSessionID: UUID?
    var pendingNotificationDestination: NotificationNavigationDestination?
    var isPresentingDailyTaskComposer = false
    var isPresentingFocusImmersion = false
    /// 由 AutomationTick 与页面 onAppear 刷新，驱动日课跨零点重渲染。
    var dailyLessonDay: Date = Calendar.current.startOfDay(for: .now)
    /// 日课、专注或真实学习活动变更时递增，驱动热力图重新聚合。
    var dailyLessonRevision = 0
    /// 专注计时每秒心跳，仅驱动视图重绘；真实剩余时间由会话时间戳推导。
    var focusTick: Date = .now

    var domainProgress: [DomainProgressSnapshot] = []
    var todayMasteryChanges: [DashboardMetric] = []
    var todayXPGains: [XPGainItem] = []
    var forgettingProjections: [ForgettingProjection] = []
    var learningRecommendations: [LearningRecommendation] = []

    @ObservationIgnored let aiClient: any AIProviderClient
    @ObservationIgnored let keychain: KeychainStore
    @ObservationIgnored let masteryEstimator: MasteryEstimator
    @ObservationIgnored let assessmentAdaptiveEngine: AssessmentAdaptiveEngine
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
    @ObservationIgnored var isAssessmentReadyNotificationDeliveryInFlight = false
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
    @ObservationIgnored var masteryEstimateByTrackKey: [String: MasteryEstimate] = [:]
    @ObservationIgnored var observationsByNodeID: [UUID: [MasteryObservation]] = [:]
    @ObservationIgnored var itemsBySessionID: [UUID: [AssessmentItem]] = [:]
    @ObservationIgnored var responsesBySessionID: [UUID: [AssessmentResponse]] = [:]
    @ObservationIgnored var performanceReceiptsByNodeID: [UUID: [PerformanceReceipt]] = [:]
    @ObservationIgnored var dailyTaskByID: [UUID: DailyTask] = [:]
    @ObservationIgnored var dailyTaskLogsByTaskID: [UUID: [DailyTaskLog]] = [:]
    @ObservationIgnored var focusTickerTask: Task<Void, Never>?
    @ObservationIgnored var statusMessageDismissalTask: Task<Void, Never>?
    /// 备题请求由发起视图登记；这样菜单栏和当前页面都能取消同一个 URLSession 并等待其收尾。
    @ObservationIgnored var assessmentGenerationTask: Task<Void, Never>?
    @ObservationIgnored var assessmentGenerationTaskID: UUID?
    @ObservationIgnored var automationStarted = false

    var supportsMeasurementModels: Bool {
        modelContainer.schema.entities.contains { $0.name == String(describing: AssessmentSession.self) }
    }

    init(
        modelContainer: ModelContainer,
        aiClient: any AIProviderClient = OpenAICompatibleClient(),
        keychain: KeychainStore = .shared,
        masteryEstimator: MasteryEstimator = MasteryEstimator(),
        assessmentAdaptiveEngine: AssessmentAdaptiveEngine = AssessmentAdaptiveEngine(),
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
        self.masteryEstimator = masteryEstimator
        self.assessmentAdaptiveEngine = assessmentAdaptiveEngine
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
        self.automaticAssessmentPreparationEnabled = automationPreferences.assessmentPreparationEnabled
        if let storedID = UserDefaults.standard.string(forKey: "activeEndpointID") {
            activeEndpointID = UUID(uuidString: storedID)
        }
        let client = self.aiClient
        Task { [weak self] in
            await client.setCapabilityUpdateHandler { [weak self] endpointID, supports in
                Task { @MainActor in
                    self?.updateEndpointStructuredOutputsCapability(profileID: endpointID, supports: supports)
                }
            }
        }
        load()
        migrateLegacyRemoteGitSourcesIfNeeded()
        cleanupLegacyDemoDataIfNeeded()
        cleanupUnverifiedChallengeCompletionIfNeeded()
        cleanupDuplicateActivityEventsIfNeeded()
        cleanupOrphanedPendingActivitiesIfNeeded()
        load()
        reconcileMeasurementSystemVersion()
        selectedKnowledgeNodeID = nil
    }

    func updateEndpointStructuredOutputsCapability(profileID: UUID, supports: Bool) {
        guard let profile = endpointProfiles.first(where: { $0.id == profileID }) else { return }
        if profile.supportsStructuredOutputs != supports {
            profile.supportsStructuredOutputs = supports
            try? modelContext.save()
            AppLogger.ai.info("Endpoint \(profile.name) supportsStructuredOutputs updated to \(supports)")
        }
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

    var requiresMeasurementReset: Bool {
        automationDefaults.integer(forKey: AppConstants.measurementSystemVersionKey) < AppConstants.currentMeasurementSystemVersion &&
            hasResettableMeasurementData
    }

    private var hasResettableMeasurementData: Bool {
        !knowledgeNodes.isEmpty ||
            !knowledgeEdges.isEmpty ||
            !evidenceRecords.isEmpty ||
            !masteryStates.isEmpty ||
            !scoreLedgerEntries.isEmpty ||
            !taxonomySuggestions.isEmpty ||
            !reviewPlans.isEmpty ||
            !memoryStates.isEmpty ||
            !memoryReviewEvents.isEmpty ||
            !challenges.isEmpty ||
            !challengeAutomationStates.isEmpty ||
            !realmAdvancementEvents.isEmpty ||
            !automationReceipts.isEmpty ||
            !digests.isEmpty ||
            !assessmentSessions.isEmpty ||
            !assessmentItems.isEmpty ||
            !assessmentResponses.isEmpty ||
            !masteryObservations.isEmpty ||
            !masteryEstimates.isEmpty ||
            !performanceReceipts.isEmpty
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
        let nodeEstimates = MasteryDimension.allCases.reduce(into: [MasteryDimension: MasteryEstimate]()) { result, dimension in
            let key = MasteryEstimate.key(nodeID: nodeID, dimension: dimension)
            result[dimension] = masteryEstimateByTrackKey[key]
        }
        let nodeObservations = (observationsByNodeID[nodeID] ?? []).filter { !$0.isInvalidated }
        let observationsByResponse = Dictionary(grouping: nodeObservations, by: \.responseID)
        let uniqueResponseCount = observationsByResponse.count
        let observationCount = uniqueResponseCount
        let vector = MasteryVector(
            exposure: max(state.vector.exposure, (nodeEstimates[.exposure]?.probability ?? 0) * 100),
            understanding: max(state.vector.understanding, (nodeEstimates[.understanding]?.probability ?? 0) * 100),
            practice: max(state.vector.practice, (nodeEstimates[.practice]?.probability ?? 0) * 100),
            retention: max(state.vector.retention, (nodeEstimates[.retention]?.probability ?? 0) * 100),
            autonomy: max(state.vector.autonomy, (nodeEstimates[.autonomy]?.probability ?? 0) * 100)
        )
        var current = vector
        current.retention = currentRetention(for: nodeID, now: now) ?? vector.retention
        let rawStage = MasteryStage.stage(for: current.composite)
        let nodeReceipts = (performanceReceiptsByNodeID[nodeID] ?? [])
            .filter {
                $0.assistanceMode == .declaredUnassisted &&
                    ProductionPerformanceGrade.grade(for: $0.score).isPassing &&
                    ($0.verificationLevel == .productionDeterministic || $0.scoringConfidence >= 0.8)
            }
            .sorted { $0.occurredAt < $1.occurredAt }
        let distinctContexts = Dictionary(grouping: nodeReceipts, by: \.contextHash).values.compactMap(\.first)
        let hasProduction = !distinctContexts.isEmpty
        let hasSeparatedProductions = distinctContexts.contains { first in
            distinctContexts.contains { second in
                first.id != second.id && abs(second.occurredAt.timeIntervalSince(first.occurredAt)) >= 7 * 86_400
            }
        }
        // 融会印证至少需要 2 个不同题目的独立全对表现，杜绝单题蒙对即点亮「已印证」
        let passingResponseThreshold = 2
        let passingChoiceResponseCount = observationsByResponse.values.count { responses in
            !responses.isEmpty && responses.allSatisfy(\.isCorrect)
        }
        let hasPassingChoiceAssessment = passingChoiceResponseCount >= passingResponseThreshold
        let hasDirectAssessment = hasPassingChoiceAssessment || hasProduction

        let certifiedStage: MasteryStage
        let stageBlockReason: String?
        // 记忆自然回落导致的境界下降只影响当前状态，需给出与 gate 缺口不同的解释：
        // 未衰减的掌握（历史 retention 维度）能支撑的境界高于当前衰减后境界时，说明差距来自遗忘而非证据缺口
        let decayDroppedStage = MasteryStage.stage(for: vector.composite).level > rawStage.level
        if rawStage.level >= MasteryStage.integrated.level && !hasDirectAssessment {
            certifiedStage = .proficient
            stageBlockReason = "融会需要至少一次独立主动验证"
        } else if rawStage.level >= MasteryStage.mastered.level && !hasSeparatedProductions {
            if !hasProduction {
                certifiedStage = hasDirectAssessment ? .integrated : .proficient
                stageBlockReason = hasDirectAssessment ? "化用与通达需要生产性实作" : "融会需要主动验证，通达需要间隔生产性实作"
            } else {
                certifiedStage = .connected
                stageBlockReason = "通达需要两次不同情境、间隔至少 7 天的生产性实作"
            }
        } else if rawStage.level >= MasteryStage.connected.level && !hasProduction {
            certifiedStage = hasDirectAssessment ? .integrated : .proficient
            stageBlockReason = hasDirectAssessment ? "选择题最多认证至融会；化用需要生产性实作" : "融会需要主动验证，化用需要生产性实作"
        } else if decayDroppedStage {
            certifiedStage = rawStage
            stageBlockReason = "记忆自然回落影响当前状态；温故即可恢复，历史境界与知验不受影响"
        } else {
            certifiedStage = rawStage
            stageBlockReason = nil
        }
        let correctResponseCount = observationsByResponse.values.count { responses in
            !responses.isEmpty && responses.allSatisfy(\.isCorrect)
        }
        let incorrectResponseCount = observationsByResponse.values.count { responses in
            responses.contains(where: { !$0.isCorrect })
        }
        let measurementStatus: MasteryMeasurementStatus
        if uniqueResponseCount == 0 {
            measurementStatus = .unmeasured
        } else if correctResponseCount >= 3 && incorrectResponseCount >= 1 {
            measurementStatus = .calibrated
        } else if uniqueResponseCount >= 1 {
            measurementStatus = .supported
        } else {
            measurementStatus = .initial
        }
        return MasteryReadinessSnapshot(
            knowledgeNodeID: nodeID,
            historicalVector: state.vector,
            artifactFoundationVector: state.artifactVector,
            currentVector: current,
            historicalStage: state.highestStage,
            currentStage: rawStage,
            certifiedStage: certifiedStage,
            measurementStatus: measurementStatus,
            observationCount: observationCount,
            hasPassingDirectAssessment: hasDirectAssessment,
            lastMeasuredAt: nodeEstimates.values.compactMap(\.lastObservedAt).max(),
            stageBlockReason: stageBlockReason
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
        evidenceByNodeID[nodeID]?.first(where: { $0.verificationLevel.isDirectPerformance })?.summary
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

    func confirmMeasurementSystemReset() throws {
        try clearAnalysisHistory()
        automationDefaults.set(AppConstants.currentMeasurementSystemVersion, forKey: AppConstants.measurementSystemVersionKey)
        statusMessage = "旧分析结果已清理；原始活动与配置已保留，请重新分析并完成主动验证"
    }

    func reconcileMeasurementSystemVersion() {
        // Only empty stores can be acknowledged automatically. Existing analysis
        // must remain untouched until the user explicitly confirms the reset.
        guard !hasResettableMeasurementData else { return }
        automationDefaults.set(AppConstants.currentMeasurementSystemVersion, forKey: AppConstants.measurementSystemVersionKey)
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
            dailyTasks = try modelContext.fetch(FetchDescriptor<DailyTask>(sortBy: [SortDescriptor(\.createdAt)]))
            dailyTaskLogs = try modelContext.fetch(
                FetchDescriptor<DailyTaskLog>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
            )
            focusSessions = try modelContext.fetch(
                FetchDescriptor<FocusSession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
            )
            digests = try modelContext.fetch(FetchDescriptor<DailyDigest>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
            taxonomySuggestions = try modelContext.fetch(FetchDescriptor<TaxonomySuggestion>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            reviewPlans = try modelContext.fetch(FetchDescriptor<ReviewPlan>(sortBy: [SortDescriptor(\.scheduledAt)]))
            memoryStates = try modelContext.fetch(FetchDescriptor<MemoryState>())
            memoryReviewEvents = try modelContext.fetch(
                FetchDescriptor<MemoryReviewEvent>(sortBy: [SortDescriptor(\.reviewedAt)])
            )
            if supportsMeasurementModels {
                assessmentSessions = try modelContext.fetch(
                    FetchDescriptor<AssessmentSession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
                )
                assessmentItems = try modelContext.fetch(FetchDescriptor<AssessmentItem>())
                assessmentResponses = try modelContext.fetch(
                    FetchDescriptor<AssessmentResponse>(sortBy: [SortDescriptor(\.answeredAt)])
                )
                masteryObservations = try modelContext.fetch(
                    FetchDescriptor<MasteryObservation>(sortBy: [SortDescriptor(\.observedAt)])
                )
                masteryEstimates = try modelContext.fetch(FetchDescriptor<MasteryEstimate>())
                performanceReceipts = try modelContext.fetch(
                    FetchDescriptor<PerformanceReceipt>(sortBy: [SortDescriptor(\.occurredAt)])
                )
            } else {
                assessmentSessions = []
                assessmentItems = []
                assessmentResponses = []
                masteryObservations = []
                masteryEstimates = []
                performanceReceipts = []
            }
            refreshActivityCounts()
            rebuildIndexes()
            if try reconcileArtifactCoverageModelIfNeeded() {
                rebuildIndexes()
            }
            reconcileActiveEndpointSelection()
            updateSnapshots()
            if retireRedundantPreparedAssessments() > 0 {
                try modelContext.save()
                updateSnapshots()
            }
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
        masteryEstimateByTrackKey = Dictionary(uniqueKeysWithValues: masteryEstimates.map { ($0.trackKey, $0) })
        observationsByNodeID = Dictionary(grouping: masteryObservations, by: \.knowledgeNodeID)
        itemsBySessionID = Dictionary(grouping: assessmentItems, by: \.sessionID)
        responsesBySessionID = Dictionary(grouping: assessmentResponses, by: \.sessionID)
        performanceReceiptsByNodeID = Dictionary(grouping: performanceReceipts, by: \.knowledgeNodeID)
        dailyTaskByID = Dictionary(uniqueKeysWithValues: dailyTasks.map { ($0.id, $0) })
        dailyTaskLogsByTaskID = Dictionary(grouping: dailyTaskLogs, by: \.taskID)
            .mapValues { $0.sorted { $0.day < $1.day } }
        recoverFocusSessionsIfNeeded()
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

extension AppState {
    func registerAssessmentGenerationTask(_ task: Task<Void, Never>, id: UUID) {
        assessmentGenerationTask = task
        assessmentGenerationTaskID = id
    }

    func finishAssessmentGenerationTask(id: UUID) {
        guard assessmentGenerationTaskID == id else { return }
        assessmentGenerationTask = nil
        assessmentGenerationTaskID = nil
    }

    func cancelAssessmentGeneration() {
        guard isGeneratingAssessment || assessmentGenerationTask != nil else { return }
        assessmentPreparationMessage = "正在取消备题请求…"
        assessmentGenerationTask?.cancel()
    }

    func challengeRequirementDescriptions(for challenge: Challenge) -> [String] {
        challengeAutomationStates
            .first(where: { $0.challengeID == challenge.id })?
            .requirement
            .descriptions
            ?? challenge.requirements
    }
}
