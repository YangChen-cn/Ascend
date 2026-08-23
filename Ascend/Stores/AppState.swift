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

    @ObservationIgnored private let aiClient: any AIProviderClient
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let scoringEngine: ScoringEngine
    @ObservationIgnored private let gitConnector: GitActivityConnector
    @ObservationIgnored private let markdownConnector: MarkdownActivityConnector
    @ObservationIgnored private let digestScheduler: DigestScheduler

    init(
        modelContainer: ModelContainer,
        aiClient: any AIProviderClient = OpenAICompatibleClient(),
        keychain: KeychainStore = .shared,
        scoringEngine: ScoringEngine = ScoringEngine(),
        gitConnector: GitActivityConnector = GitActivityConnector(),
        markdownConnector: MarkdownActivityConnector = MarkdownActivityConnector(),
        digestScheduler: DigestScheduler = DigestScheduler()
    ) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        self.aiClient = aiClient
        self.keychain = keychain
        self.scoringEngine = scoringEngine
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

    var domainProgress: [DomainProgressSnapshot] {
        Dictionary(grouping: knowledgeNodes, by: \.domain)
            .map { domain, nodes in
                let states = nodes.compactMap { mastery(for: $0.id) }
                let score = states.isEmpty ? 0 : states.reduce(0) { $0 + $1.composite } / Double(states.count)
                let xp = states.reduce(0) { $0 + $1.lifetimeXP }
                return DomainProgressSnapshot(
                    name: domain,
                    score: score,
                    xp: xp,
                    knowledgeCount: nodes.count,
                    realm: DomainRealm.resolve(score: score, xp: xp)
                )
            }
            .sorted { lhs, rhs in lhs.xp == rhs.xp ? lhs.name < rhs.name : lhs.xp > rhs.xp }
    }

    var todayMasteryChanges: [DashboardMetric] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: scoreLedgerEntries.filter { calendar.isDateInToday($0.timestamp) }, by: \.knowledgeNodeID)
        return grouped.compactMap { nodeID, entries in
            guard let node = node(for: nodeID),
                  let first = entries.min(by: { $0.timestamp < $1.timestamp }),
                  let last = entries.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
            return DashboardMetric(
                title: node.name,
                previous: Int(first.previousComposite.rounded()),
                current: Int(last.newComposite.rounded())
            )
        }.sorted { ($0.current - $0.previous) > ($1.current - $1.previous) }
    }

    var todayXPGains: [XPGainItem] {
        let calendar = Calendar.current
        let todayEntries = scoreLedgerEntries.filter { calendar.isDateInToday($0.timestamp) }
        let evidenceByID = Dictionary(uniqueKeysWithValues: evidenceRecords.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: todayEntries) { entry in
            evidenceByID[entry.evidenceID]?.kind ?? .exposure
        }
        return grouped.map { kind, entries in
            XPGainItem(title: kind.title, systemImage: icon(for: kind), xp: entries.reduce(0) { $0 + $1.xpAwarded })
        }.sorted { $0.xp > $1.xp }
    }

    var forgettingProjections: [ForgettingProjection] {
        knowledgeNodes.compactMap { node in
            guard let state = mastery(for: node.id), state.lastEvidenceAt != nil else { return nil }
            let projected = scoringEngine.projectDecay(
                state.vector,
                stabilityDays: state.stabilityDays,
                lastEvidenceAt: state.lastEvidenceAt,
                now: .now
            )
            let loss = Int((state.composite - projected.composite).rounded())
            guard loss > 0 else { return nil }
            return ForgettingProjection(node: node, scoreLoss: loss, retention: projected.retention)
        }.sorted { $0.scoreLoss > $1.scoreLoss }
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
        let target = profile ?? AIEndpointProfile(name: draft.name, baseURLString: draft.baseURLString)
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
        if activeEndpointID == nil { setActiveEndpoint(target.id) }
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
        guard !isAnalyzing else { return }
        isAnalyzing = true
        statusMessage = nil
        defer { isAnalyzing = false }

        do {
            try await scanSources()
            let pending = activityEvents.filter { !$0.isProcessed }
            guard !pending.isEmpty else {
                statusMessage = "没有新的学习活动需要分析"
                return
            }
            let selectedProfileID = endpointOverride ?? activeEndpointID
            guard let profile = endpointProfiles.first(where: { $0.id == selectedProfileID }) else {
                throw AppStateError.missingEndpoint
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
            let activities = pending.map { event in
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
                let key = try await keychain.apiKey(endpointID: profile.id) ?? ""
                let envelope = try await aiClient.analyze(
                    endpoint: descriptor,
                    modelID: modelID,
                    apiKey: key,
                    activities: activities,
                    candidateNodes: candidates
                )
                try apply(envelope: envelope, to: pending, analysisRun: run)
                run.status = "completed"
                run.completedAt = .now
                try modelContext.save()
                load()
                statusMessage = "已分析 \(pending.count) 条活动"
                try? await digestScheduler.sendDigestReadyNotification(summary: envelope.sessionSummary)
            } catch {
                run.status = "failed"
                run.errorMessage = error.localizedDescription
                run.completedAt = .now
                try modelContext.save()
                throw error
            }
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
                ExportedSource(id: $0.id, name: $0.name, kind: $0.kind, path: $0.path, isEnabled: $0.isEnabled, analyzeWorkingTree: $0.analyzeWorkingTree)
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
                    analyzeWorkingTree: item.analyzeWorkingTree
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

    private func apply(envelope: AnalysisEnvelope, to events: [ActivityEvent], analysisRun: AnalysisRun) throws {
        let eventByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        var xpEarned = 0
        for analyzed in envelope.evidence {
            guard let event = eventByID[analyzed.activityID] else { continue }
            let node = resolveNode(for: analyzed)
            let isVerified = analyzed.matchConfidence >= 0.85
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
            if isVerified {
                xpEarned += applyScoring(evidence: evidence, node: node)
            } else {
                modelContext.insert(
                    TaxonomySuggestion(
                        suggestionType: "reviewEvidence",
                        proposedName: analyzed.knowledgeName,
                        relatedNodeID: node.id,
                        rationale: analyzed.rationale,
                        confidence: analyzed.matchConfidence
                    )
                )
            }
            event.isProcessed = true
        }

        for suggestion in envelope.nodeSuggestions {
            guard !knowledgeNodes.contains(where: { $0.name.localizedStandardCompare(suggestion.proposedName) == .orderedSame }) else { continue }
            let node = KnowledgeNode(name: suggestion.proposedName, domain: suggestion.domain, isProvisional: true)
            modelContext.insert(node)
            modelContext.insert(MasteryState(knowledgeNodeID: node.id))
            modelContext.insert(
                TaxonomySuggestion(
                    suggestionType: "newNode",
                    proposedName: suggestion.proposedName,
                    relatedNodeID: node.id,
                    rationale: suggestion.rationale,
                    confidence: suggestion.confidence
                )
            )
        }

        if let suggestion = envelope.challengeSuggestion {
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
        modelContext.insert(DailyDigest(date: .now, summary: envelope.sessionSummary, xpEarned: xpEarned))
    }

    private func resolveNode(for analyzed: AnalyzedEvidence) -> KnowledgeNode {
        if analyzed.matchConfidence >= 0.85,
           let matchedNodeID = analyzed.matchedNodeID,
           let matched = knowledgeNodes.first(where: { $0.id == matchedNodeID }) {
            return matched
        }
        if let named = knowledgeNodes.first(where: { $0.name.localizedStandardCompare(analyzed.knowledgeName) == .orderedSame }) {
            return named
        }
        let node = KnowledgeNode(name: analyzed.knowledgeName, domain: "待分类", isProvisional: true)
        modelContext.insert(node)
        let state = MasteryState(knowledgeNodeID: node.id)
        modelContext.insert(state)
        knowledgeNodes.append(node)
        masteryStates.append(state)
        return node
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
        let evidence = evidenceRecords.filter { $0.knowledgeNodeID == nodeID && $0.isVerified }
        let weighted = evidence.reduce(0.0) { result, item in
            let ageDays = max(0, Date.now.timeIntervalSince(item.timestamp) / 86_400)
            return result + item.aiConfidence * exp(-ageDays / 90)
        }
        return 100 * (1 - exp(-weighted / 6))
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
        } catch {
            statusMessage = "读取本地数据失败：\(error.localizedDescription)"
        }
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
}
