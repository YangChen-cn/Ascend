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
    var statusMessage: String?
    var endpointProfiles: [AIEndpointProfile] = []
    var sources: [SourceConfiguration] = []
    var activityEvents: [ActivityEvent] = []
    var evidenceRecords: [EvidenceRecord] = []
    var knowledgeNodes: [KnowledgeNode] = []
    var masteryStates: [MasteryState] = []
    var knowledgeEdges: [KnowledgeEdge] = []
    var scoreLedgerEntries: [ScoreLedgerEntry] = []
    var challenges: [Challenge] = []
    var digests: [DailyDigest] = []
    var taxonomySuggestions: [TaxonomySuggestion] = []
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

    init(
        modelContainer: ModelContainer,
        aiClient: any AIProviderClient = OpenAICompatibleClient(),
        keychain: KeychainStore = .shared,
        scoringEngine: ScoringEngine = ScoringEngine(),
        analyticsEngine: AnalyticsEngine = AnalyticsEngine(),
        gitConnector: GitActivityConnector = GitActivityConnector(),
        markdownConnector: MarkdownActivityConnector = MarkdownActivityConnector(),
        digestScheduler: DigestScheduler = DigestScheduler()
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
        if let storedID = UserDefaults.standard.string(forKey: "activeEndpointID") {
            activeEndpointID = UUID(uuidString: storedID)
        }
        load()
        cleanupLegacyDemoDataIfNeeded()
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

    func mastery(for nodeID: UUID) -> MasteryState? {
        masteryStates.first { $0.knowledgeNodeID == nodeID }
    }

    func node(for nodeID: UUID) -> KnowledgeNode? {
        knowledgeNodes.first { $0.id == nodeID }
    }

    func latestInsight(for nodeID: UUID) -> String? {
        evidenceRecords.first { $0.knowledgeNodeID == nodeID && $0.isVerified }?.summary
    }

    func weeklyChange(for nodeID: UUID) -> Int {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        return Int(scoreLedgerEntries
            .filter { $0.knowledgeNodeID == nodeID && $0.timestamp >= start }
            .reduce(0) { $0 + max(0, $1.newComposite - $1.previousComposite) }
            .rounded())
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
        load()
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
        if activeEndpoint == nil { setActiveEndpoint(target.id) }
        load()
    }

    func deleteEndpoint(_ profile: AIEndpointProfile) async throws {
        modelContext.delete(profile)
        try modelContext.save()
        try await keychain.deleteAPIKey(endpointID: profile.id)
        if activeEndpointID == profile.id { setActiveEndpoint(endpointProfiles.first { $0.id != profile.id }?.id) }
        load()
    }

    func addSource(name: String, kind: SourceKind, path: String) throws {
        guard !sources.contains(where: { $0.path == path && $0.kind == kind }) else {
            throw AppStateError.duplicateSource
        }
        modelContext.insert(SourceConfiguration(name: name, kind: kind, path: path))
        try modelContext.save()
        load()
    }

    func deleteSource(_ source: SourceConfiguration) throws {
        modelContext.delete(source)
        try modelContext.save()
        load()
    }

    func reload() {
        load()
    }

    func saveChanges() {
        do {
            try modelContext.save()
            load()
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    func scanSources() async throws {
        guard isCollecting else { return }
        let knownFingerprints = Set(activityEvents.map(\.fingerprint))
        var insertedFingerprints = knownFingerprints
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
            let collected: [CollectedActivity]
            switch source.kind {
            case .gitRepository:
                collected = try await gitConnector.scan(source: descriptor)
            case .markdownDirectory:
                collected = try await markdownConnector.scan(source: descriptor)
            case .manual:
                collected = []
            }
            for item in collected where !insertedFingerprints.contains(item.fingerprint) {
                modelContext.insert(
                    ActivityEvent(
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
                )
                insertedFingerprints.insert(item.fingerprint)
            }
            source.lastScannedAt = .now
        }
        try modelContext.save()
        load()
        AppLogger.collector.info("Source scan completed with \(self.activityEvents.count) total activities")
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
            let selectedActivities: [ActivityEvent]
            if let targetActivityIDs {
                selectedActivities = activityEvents.filter { targetActivityIDs.contains($0.id) }
            } else {
                selectedActivities = activityEvents.filter { !$0.isProcessed }
            }
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
                    KnowledgeCandidate(id: node.id, name: node.name, domain: node.domain, mastery: mastery(for: node.id)?.composite ?? 0)
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
                    load()
                } catch {
                    modelContext.rollback()
                    run.status = "failed"
                    run.errorMessage = error.localizedDescription
                    run.completedAt = .now
                    try modelContext.save()
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
        try modelContext.save()
        load()
        selectedKnowledgeNodeID = knowledgeNodes.first?.id
    }

    func clearAllData() async throws {
        for endpoint in endpointProfiles { try await keychain.deleteAPIKey(endpointID: endpoint.id) }
        try modelContext.delete(model: AIEndpointProfile.self)
        try modelContext.delete(model: SourceConfiguration.self)
        try modelContext.delete(model: ActivityEvent.self)
        try modelContext.delete(model: EvidenceRecord.self)
        try modelContext.delete(model: KnowledgeNode.self)
        try modelContext.delete(model: KnowledgeEdge.self)
        try modelContext.delete(model: MasteryState.self)
        try modelContext.delete(model: ScoreLedgerEntry.self)
        try modelContext.delete(model: TaxonomySuggestion.self)
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
                modelContext.insert(
                    TaxonomySuggestion(
                        suggestionType: "newNode",
                        proposedName: node.name,
                        relatedNodeID: node.id,
                        activityID: analyzed.activityID,
                        rationale: nodeSuggestion?.rationale ?? analyzed.rationale,
                        confidence: nodeSuggestion?.confidence ?? analyzed.confidence
                    )
                )
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
            if isVerified {
                xpEarned += applyScoring(evidence: evidence, node: node)
            } else {
                modelContext.insert(
                    TaxonomySuggestion(
                        suggestionType: "reviewEvidence",
                        proposedName: analyzed.knowledgeName,
                        relatedNodeID: node.id,
                        activityID: analyzed.activityID,
                        rationale: analyzed.rationale,
                        confidence: analyzed.matchConfidence
                    )
                )
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
            modelContext.insert(
                Challenge(
                    title: suggestion.title,
                    challengeDescription: suggestion.description,
                    estimatedMinutes: suggestion.estimatedMinutes,
                    knowledgeNodeIDs: [],
                    requirements: suggestion.requirements,
                    rewardXP: suggestion.rewardXP
                )
            )
        }
        if createsAggregateResults {
            modelContext.insert(DailyDigest(date: .now, summary: envelope.sessionSummary, xpEarned: xpEarned))
        }
        return xpEarned
    }

    func clearAnalysisHistory() throws {
        try modelContext.delete(model: EvidenceRecord.self)
        try modelContext.delete(model: KnowledgeEdge.self)
        try modelContext.delete(model: MasteryState.self)
        try modelContext.delete(model: ScoreLedgerEntry.self)
        try modelContext.delete(model: TaxonomySuggestion.self)
        try modelContext.delete(model: Challenge.self)
        try modelContext.delete(model: DailyDigest.self)
        try modelContext.delete(model: AnalysisRun.self)
        try modelContext.delete(model: KnowledgeNode.self)
        activityEvents.forEach { $0.isProcessed = false }
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

    func approveSuggestion(_ suggestion: TaxonomySuggestion) {
        guard suggestion.status == "pending" else { return }
        if suggestion.suggestionType == "reviewEvidence" {
            if let nodeID = suggestion.relatedNodeID,
               let node = node(for: nodeID),
               let unverified = evidenceRecords.first(where: { $0.knowledgeNodeID == nodeID && !$0.isVerified }) {
                unverified.isVerified = true
                let xp = applyScoring(evidence: unverified, node: node)
                statusMessage = "已批准证据并记入 \(xp) XP"
            }
        } else if suggestion.suggestionType == "newNode" {
            if let nodeID = suggestion.relatedNodeID, let node = node(for: nodeID) {
                node.isProvisional = false
                statusMessage = "已收录知识点“\(node.name)”"
            }
        }
        suggestion.status = "approved"
        try? modelContext.save()
        load()
    }

    func rejectSuggestion(_ suggestion: TaxonomySuggestion) {
        guard suggestion.status == "pending" else { return }
        if suggestion.suggestionType == "reviewEvidence" {
            if let nodeID = suggestion.relatedNodeID,
               let unverified = evidenceRecords.first(where: { $0.knowledgeNodeID == nodeID && !$0.isVerified }) {
                modelContext.delete(unverified)
            }
        } else if suggestion.suggestionType == "newNode" {
            if let nodeID = suggestion.relatedNodeID,
               let node = node(for: nodeID),
               !evidenceRecords.contains(where: { $0.knowledgeNodeID == nodeID && $0.isVerified }) {
                if let state = mastery(for: nodeID) {
                    modelContext.delete(state)
                }
                modelContext.delete(node)
            }
        }
        suggestion.status = "rejected"
        statusMessage = "已忽略该建议"
        try? modelContext.save()
        load()
    }

    func mergeSuggestion(_ suggestion: TaxonomySuggestion, into targetNodeID: UUID) {
        guard suggestion.status == "pending", let targetNode = node(for: targetNodeID) else { return }
        if suggestion.suggestionType == "reviewEvidence" {
            if let oldNodeID = suggestion.relatedNodeID,
               let unverified = evidenceRecords.first(where: { $0.knowledgeNodeID == oldNodeID && !$0.isVerified }) {
                unverified.knowledgeNodeID = targetNodeID
                unverified.isVerified = true
                let xp = applyScoring(evidence: unverified, node: targetNode)
                statusMessage = "已将证据合并至“\(targetNode.name)”，记入 \(xp) XP"
            }
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
                    if let state = mastery(for: oldNodeID) { modelContext.delete(state) }
                    modelContext.delete(oldNode)
                }
                statusMessage = "已将“\(suggestion.proposedName)”合并至“\(targetNode.name)”"
            }
        }
        suggestion.status = "merged"
        try? modelContext.save()
        load()
    }

    func approveAllPendingSuggestions() {
        let pending = taxonomySuggestions.filter { $0.status == "pending" }
        guard !pending.isEmpty else { return }
        for suggestion in pending {
            if suggestion.suggestionType == "reviewEvidence" {
                if let nodeID = suggestion.relatedNodeID,
                   let node = node(for: nodeID),
                   let unverified = evidenceRecords.first(where: { $0.knowledgeNodeID == nodeID && !$0.isVerified }) {
                    unverified.isVerified = true
                    _ = applyScoring(evidence: unverified, node: node)
                }
            } else if suggestion.suggestionType == "newNode" {
                if let nodeID = suggestion.relatedNodeID, let node = node(for: nodeID) {
                    node.isProvisional = false
                }
            }
            suggestion.status = "approved"
        }
        statusMessage = "已批量确认 \(pending.count) 条待审核建议"
        try? modelContext.save()
        load()
    }

    func updateChallengeStatus(_ challenge: Challenge, status: String) {
        challenge.status = status
        if status == "completed" {
            statusMessage = "恭喜完成挑战“\(challenge.title)”！"
        } else if status == "in_progress" {
            statusMessage = "已接取挑战“\(challenge.title)”，开始实践吧！"
        } else {
            statusMessage = "已更新挑战状态"
        }
        try? modelContext.save()
        load()
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
        return (node, true)
    }

    private func applyScoring(evidence: EvidenceRecord, node: KnowledgeNode) -> Int {
        let state = masteryStates.first(where: { $0.knowledgeNodeID == node.id }) ?? {
            let created = MasteryState(knowledgeNodeID: node.id)
            modelContext.insert(created)
            masteryStates.append(created)
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
        modelContext.insert(
            ScoreLedgerEntry(
                evidenceID: evidence.id,
                knowledgeNodeID: node.id,
                timestamp: evidence.timestamp,
                previousComposite: result.previousComposite,
                newComposite: result.newComposite,
                xpAwarded: result.xpAwarded,
                reason: evidence.rationale
            )
        )
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
        domainProgress = analyticsEngine.computeDomainProgress(nodes: knowledgeNodes, masteryStates: masteryStates)
        todayMasteryChanges = analyticsEngine.computeTodayMasteryChanges(nodes: knowledgeNodes, ledgerEntries: scoreLedgerEntries)
        todayXPGains = analyticsEngine.computeTodayXPGains(evidenceRecords: evidenceRecords, ledgerEntries: scoreLedgerEntries)
        forgettingProjections = analyticsEngine.computeForgettingProjections(nodes: knowledgeNodes, masteryStates: masteryStates, scoringEngine: scoringEngine)
    }

    private func load() {
        do {
            endpointProfiles = try modelContext.fetch(FetchDescriptor<AIEndpointProfile>(sortBy: [SortDescriptor(\.name)]))
            sources = try modelContext.fetch(FetchDescriptor<SourceConfiguration>(sortBy: [SortDescriptor(\.name)]))
            activityEvents = try modelContext.fetch(FetchDescriptor<ActivityEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)]))
            evidenceRecords = try modelContext.fetch(FetchDescriptor<EvidenceRecord>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)]))
            knowledgeNodes = try modelContext.fetch(FetchDescriptor<KnowledgeNode>(sortBy: [SortDescriptor(\.name)]))
            masteryStates = try modelContext.fetch(FetchDescriptor<MasteryState>())
            knowledgeEdges = try modelContext.fetch(FetchDescriptor<KnowledgeEdge>())
            scoreLedgerEntries = try modelContext.fetch(FetchDescriptor<ScoreLedgerEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)]))
            challenges = try modelContext.fetch(FetchDescriptor<Challenge>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            digests = try modelContext.fetch(FetchDescriptor<DailyDigest>(sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]))
            taxonomySuggestions = try modelContext.fetch(FetchDescriptor<TaxonomySuggestion>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            reconcileActiveEndpointSelection()
            updateSnapshots()
        } catch {
            statusMessage = "读取本地数据失败：\(error.localizedDescription)"
        }
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

    // MARK: - 精准打开设置 Tab
    @MainActor
    func openSettings(section: SettingsSection = .general) {
        self.selectedSettingsSection = section
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil as Any?, from: nil as Any?)
        NSApp.activate(ignoringOtherApps: true)
    }
}
