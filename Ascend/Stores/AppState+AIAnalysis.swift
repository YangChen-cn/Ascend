import Foundation
import SwiftData

extension AppState {
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

    func resolvedAPIKey(draft: EndpointDraft) async throws -> String {
        if !draft.apiKey.isEmpty { return draft.apiKey }
        return try await keychain.apiKey(endpointID: draft.id) ?? ""
    }

    func runAnalysis(endpointOverride: UUID? = nil, modelOverride: String? = nil) async {
        _ = await analyzeActivities(
            endpointOverride: endpointOverride,
            modelOverride: modelOverride,
            targetActivityIDs: nil,
            overwritesExistingResults: false,
            performsPreflightScan: nil
        )
    }

    func reanalyze(activityIDs: Set<UUID>) async {
        guard !activityIDs.isEmpty else { return }
        _ = await analyzeActivities(
            endpointOverride: nil,
            modelOverride: nil,
            targetActivityIDs: activityIDs,
            overwritesExistingResults: true,
            performsPreflightScan: nil
        )
    }

    func analyzeActivities(
        endpointOverride: UUID?,
        modelOverride: String?,
        targetActivityIDs: Set<UUID>?,
        overwritesExistingResults: Bool,
        performsPreflightScan: Bool?
    ) async -> Bool {
        guard !isAnalyzing else { return false }
        isAnalyzing = true
        analysisProgressMessage = "正在准备分析…"
        defer {
            analysisProgressMessage = nil
            isAnalyzing = false
        }

        do {
            let preferences = AnalysisPreferences.current(defaults: automationDefaults)
            if targetActivityIDs == nil && (performsPreflightScan ?? preferences.scansBeforeAnalysis) {
                try await scanSources()
            }
            let selectedActivities = try fetchActivities(ids: targetActivityIDs)
            guard !selectedActivities.isEmpty else {
                statusMessage = "没有新的学习活动需要分析"
                return false
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
            let calendar = Calendar.current
            let orderedActivities = selectedActivities.sorted { $0.timestamp < $1.timestamp }
            let batches = AnalysisBatchPlanner.ranges(
                itemCount: orderedActivities.count,
                batchSize: batchSize
            ).map { range in
                Array(orderedActivities[range])
            }
            let totalBatches = batches.count
            var affectedDigestDays = Set<Date>()

            for (index, batch) in batches.enumerated() {
                analysisProgressMessage = totalBatches > 1
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
                        excerpt: String(event.excerpt.prefix(AppConstants.maximumLLMExcerptLength))
                    )
                }
                let candidates = KnowledgeCandidateSelector.selectCandidates(
                    for: activities,
                    from: knowledgeNodes,
                    relations: knowledgeEdges,
                    masteryProvider: { [weak self] nodeID in
                        self?.readiness(for: nodeID)?.currentComposite ?? 0
                    }
                )
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
                    let batchSummary = AnalysisBatchSummary(
                        analysisRunID: run.id,
                        date: calendar.startOfDay(for: batch[0].timestamp),
                        summary: envelope.sessionSummary
                    )
                    modelContext.insert(batchSummary)
                    for activity in batch {
                        let activityDay = calendar.startOfDay(for: activity.timestamp)
                        modelContext.insert(
                            AnalysisBatchActivityLink(
                                activityID: activity.id,
                                batchSummaryID: batchSummary.id,
                                activityDate: activityDay
                            )
                        )
                        affectedDigestDays.insert(activityDay)
                    }
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

            runTriggerEngine()
            let updatedDigests = try affectedDigestDays.sorted().map {
                try upsertDailyDigest(date: $0, batchSummaries: [])
            }
            try modelContext.save()

            statusMessage = overwritesExistingResults
                ? "已重新分析并覆盖 \(selectedActivities.count) 条活动"
                : "已成功分析 \(selectedActivities.count) 条活动"
            await processPendingReviewNotifications()
            await sendAssessmentReadyNotificationIfNeeded()
            Task { [weak self] in
                await Task.yield()
                await self?.evaluateAutomaticAssessmentPreparation(ignoresRetryCooldown: false)
            }
            return true
        } catch {
            statusMessage = error.localizedDescription
            AppLogger.ai.error("Analysis failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @discardableResult
    func apply(
        envelope: AnalysisEnvelope,
        to events: [ActivityEvent],
        createsAggregateResults: Bool = true
    ) throws -> Int {
        let run = AnalysisRun(
            endpointProfileID: activeEndpoint?.id,
            modelID: activeEndpoint?.selectedModelID ?? "test-model",
            activityCount: events.count
        )
        return try apply(
            envelope: envelope,
            to: events,
            analysisRun: run,
            createsAggregateResults: createsAggregateResults
        )
    }

    @discardableResult
    func apply(
        envelope: AnalysisEnvelope,
        to events: [ActivityEvent],
        analysisRun: AnalysisRun,
        createsAggregateResults: Bool = true
    ) throws -> Int {
        var totalAwardedXP = 0
        let eventByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        let suggestionByName = envelope.nodeSuggestions.reduce(into: [String: NodeSuggestion]()) { result, suggestion in
            let key = suggestion.proposedName.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            if result[key] == nil { result[key] = suggestion }
        }
        for analyzed in envelope.evidence {
            guard let event = eventByID[analyzed.activityID] else { continue }
            // 结构化判定优先：contentChangeHash 带 lowinfo: 前缀表示本地预检为低信息代码变更；
            // 旧数据没有该前缀时回退 summary 文案判定
            let isLowInformationCodeChange = event.contentChangeHash?.hasPrefix("lowinfo:") == true
                || event.summary.hasPrefix("[低信息代码变更]")
            if isLowInformationCodeChange,
               analyzed.kind == .exercise || analyzed.kind == .project || analyzed.kind == .independentSolve {
                AppLogger.ai.warning("Discarded high-value evidence from a low-information code change")
                continue
            }
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
                if masteryByNodeID[node.id] == nil {
                    let state = MasteryState(knowledgeNodeID: node.id)
                    modelContext.insert(state)
                    masteryStates.append(state)
                    masteryByNodeID[node.id] = state
                }
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
                fingerprint: event.fingerprint + "-" + node.id.uuidString,
                contentChangeHash: event.contentChangeHash,
                origin: .artifact,
                verificationLevel: .artifactCandidate,
                assistanceMode: .unknown
            )
            modelContext.insert(evidence)
            evidenceRecords.append(evidence)
            evidenceByID[evidence.id] = evidence
            evidenceByNodeID[node.id, default: []].insert(evidence, at: 0)
            totalAwardedXP += applyArtifactEvidence(evidence)
            if !isVerified {
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

        if let embeddedPackage = envelope.assessmentPackage {
            do {
                _ = try persistEmbeddedAssessmentPackage(
                    embeddedPackage,
                    activities: events,
                    generatorModelID: analysisRun.modelID
                )
            } catch {
                // 校验失败不允许静默：用户会预期"分析自带题包缓存"，必须说明原因
                AppLogger.ai.warning("Discarded invalid embedded assessment package: \(error.localizedDescription, privacy: .public)")
                assessmentPreparationMessage = "本次分析未缓存研习题包：\(error.localizedDescription)。主动研习时将按需生成（1 次 AI）。"
            }
        }

        for edge in envelope.edgeSuggestions {
            guard let sourceNode = resolveNodeByName(edge.sourceName),
                  let targetNode = resolveNodeByName(edge.targetName),
                  sourceNode.id != targetNode.id else { continue }

            let relation = KnowledgeRelation.from(rawValue: edge.relation)

            if relation == .prerequisite {
                let (canAdd, reason) = topologyEngine.canAddPrerequisite(
                    sourceNodeID: sourceNode.id,
                    targetNodeID: targetNode.id,
                    existingEdges: knowledgeEdges
                )
                guard canAdd else {
                    AppLogger.ai.info("Skipped invalid prerequisite [\(sourceNode.name) -> \(targetNode.name)]: \(reason ?? "DAG violation", privacy: .public)")
                    continue
                }
            }

            let isHighConfidence = edge.confidence >= 0.85
            let isEstablishedNodes = !sourceNode.isProvisional && !targetNode.isProvisional
            let isSameDomain = sourceNode.domain == targetNode.domain

            if isHighConfidence && isEstablishedNodes && isSameDomain {
                let exists = knowledgeEdges.contains {
                    $0.sourceNodeID == sourceNode.id &&
                    $0.targetNodeID == targetNode.id &&
                    $0.relation == relation
                }
                if !exists {
                    let newEdge = KnowledgeEdge(
                        sourceNodeID: sourceNode.id,
                        targetNodeID: targetNode.id,
                        relation: relation,
                        confidence: edge.confidence,
                        rationale: edge.rationale ?? "",
                        origin: "ai",
                        createdAt: .now
                    )
                    modelContext.insert(newEdge)
                    knowledgeEdges.append(newEdge)
                }
            } else {
                let suggestionName = "\(sourceNode.name) → \(relation.title) → \(targetNode.name)"
                let alreadySuggested = taxonomySuggestions.contains {
                    $0.status == "pending" &&
                    $0.suggestionType == "relation" &&
                    $0.sourceNodeID == sourceNode.id &&
                    $0.targetNodeID == targetNode.id &&
                    $0.relationRawValue == relation.rawValue
                }
                if !alreadySuggested {
                    let suggestion = TaxonomySuggestion(
                        suggestionType: "relation",
                        proposedName: suggestionName,
                        relatedNodeID: sourceNode.id,
                        rationale: edge.rationale ?? "AI 建议关联：\(sourceNode.name) \(relation.title) \(targetNode.name)",
                        confidence: edge.confidence,
                        sourceNodeID: sourceNode.id,
                        targetNodeID: targetNode.id,
                        relationRawValue: relation.rawValue
                    )
                    modelContext.insert(suggestion)
                    taxonomySuggestions.append(suggestion)
                }
            }
        }

        for next in envelope.possibleNextConcepts.prefix(3) {
            let normalizedName = next.proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty else { continue }
            let alreadyExists = knowledgeNodes.contains {
                $0.name.localizedStandardCompare(normalizedName) == .orderedSame
            }
            guard !alreadyExists else { continue }
            let alreadySuggested = taxonomySuggestions.contains {
                $0.status == "pending" &&
                $0.suggestionType == "nextConcept" &&
                $0.proposedName.localizedStandardCompare(normalizedName) == .orderedSame
            }
            if !alreadySuggested {
                let validPrereqIDs = Array(Set(next.prerequisiteNames.compactMap { prereqName -> UUID? in
                    resolveNodeByName(prereqName)?.id
                }))
                let suggestion = TaxonomySuggestion(
                    suggestionType: "nextConcept",
                    proposedName: normalizedName,
                    rationale: next.rationale,
                    confidence: next.confidence,
                    targetDomain: next.domain,
                    prerequisiteNodeIDs: validPrereqIDs
                )
                modelContext.insert(suggestion)
                taxonomySuggestions.append(suggestion)
            }
        }

        if createsAggregateResults, let suggestion = envelope.challengeSuggestion {
            let linkedNodeIDs = Array(Set(suggestion.knowledgeNames.compactMap { resolveNodeByName($0)?.id }))
            let alreadyExists = challenges.contains {
                $0.status != "completed" &&
                    $0.title.localizedStandardCompare(suggestion.title) == .orderedSame &&
                    Set($0.knowledgeNodeIDs) == Set(linkedNodeIDs)
            }
            if !linkedNodeIDs.isEmpty, !alreadyExists {
                let challenge = Challenge(
                    title: suggestion.title,
                    challengeDescription: suggestion.description,
                    estimatedMinutes: suggestion.estimatedMinutes,
                    knowledgeNodeIDs: linkedNodeIDs,
                    requirements: suggestion.requirement.descriptions,
                    rewardXP: suggestion.rewardXP
                )
                let automationState = ChallengeAutomationState(
                    challengeID: challenge.id,
                    requirement: suggestion.requirement
                )
                modelContext.insert(challenge)
                modelContext.insert(automationState)
                challenges.insert(challenge, at: 0)
                challengeAutomationStates.append(automationState)
            }
        }
        return totalAwardedXP
    }

    func clearAnalysisHistory() throws {
        if supportsMeasurementModels {
            try modelContext.delete(model: PerformanceReceipt.self)
            try modelContext.delete(model: MasteryObservation.self)
            try modelContext.delete(model: MasteryEstimate.self)
            try modelContext.delete(model: AssessmentResponse.self)
            try modelContext.delete(model: AssessmentItem.self)
            try modelContext.delete(model: AssessmentSession.self)
        }
        try modelContext.delete(model: EvidenceRecord.self)
        try modelContext.delete(model: KnowledgeEdge.self)
        try modelContext.delete(model: MasteryState.self)
        try modelContext.delete(model: ScoreLedgerEntry.self)
        try modelContext.delete(model: TaxonomySuggestion.self)
        try modelContext.delete(model: ReviewPlan.self)
        try modelContext.delete(model: MemoryReviewEvent.self)
        try modelContext.delete(model: MemoryState.self)
        try modelContext.delete(model: Challenge.self)
        try modelContext.delete(model: ChallengeAutomationState.self)
        try modelContext.delete(model: RealmAdvancementEvent.self)
        try modelContext.delete(model: AutomationReceipt.self)
        try modelContext.delete(model: AnalysisBatchActivityLink.self)
        try modelContext.delete(model: AnalysisBatchSummary.self)
        try modelContext.delete(model: DailyDigest.self)
        try modelContext.delete(model: AnalysisRun.self)
        try modelContext.delete(model: KnowledgeNode.self)
        try modelContext.fetch(FetchDescriptor<ActivityEvent>()).forEach { $0.isProcessed = false }
        try modelContext.save()
        selectedKnowledgeNodeID = nil
        load()
        statusMessage = "已清除分析结果；原始活动、数据源和 AI 接口均已保留"
    }

    func removeExistingAnalysis(for activityIDs: Set<UUID>) {
        removeBatchSummaries(for: activityIDs)
        let removedEvidence = evidenceRecords.filter {
            activityIDs.contains($0.activityID) && $0.verificationLevel == .artifactCandidate
        }
        let removedEvidenceIDs = Set(removedEvidence.map(\.id))
        let affectedNodeIDs = Set(removedEvidence.map(\.knowledgeNodeID))
        let removedMemoryEvents = memoryReviewEvents.filter { event in
            event.evidenceID.map(removedEvidenceIDs.contains) == true
        }
        removedMemoryEvents.forEach(modelContext.delete)
        let removedMemoryEventIDs = Set(removedMemoryEvents.map(\.id))
        memoryReviewEvents.removeAll { removedMemoryEventIDs.contains($0.id) }

        scoreLedgerEntries
            .filter { removedEvidenceIDs.contains($0.evidenceID) }
            .forEach(modelContext.delete)
        realmAdvancementEvents
            .filter { removedEvidenceIDs.contains($0.evidenceID) }
            .forEach(modelContext.delete)
        realmAdvancementEvents.removeAll { removedEvidenceIDs.contains($0.evidenceID) }
        for automation in challengeAutomationStates {
            let remainingMatches = automation.matchedEvidenceIDs.filter { !removedEvidenceIDs.contains($0) }
            guard remainingMatches.count != automation.matchedEvidenceIDs.count else { continue }
            automation.matchedEvidenceIDs = remainingMatches
            if let challenge = challenges.first(where: { $0.id == automation.challengeID }),
               challenge.status == "completed" {
                challenge.status = "in_progress"
                challenge.completedAt = nil
                automation.completedAt = nil
            }
        }
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
                memoryReviewEvents
                    .filter { $0.knowledgeNodeID == nodeID }
                    .forEach(modelContext.delete)
                if let memory = memoryByNodeID[nodeID] {
                    modelContext.delete(memory)
                }
                modelContext.delete(node)
                removedNodeIDs.insert(nodeID)
            }
        }

        evidenceRecords.removeAll { removedEvidenceIDs.contains($0.id) }
        scoreLedgerEntries.removeAll { removedEvidenceIDs.contains($0.evidenceID) }
        taxonomySuggestions.removeAll { suggestion in
            suggestion.activityID.map(activityIDs.contains) == true ||
                suggestion.relatedNodeID.map(removedNodeIDs.contains) == true
        }
        knowledgeEdges.removeAll { removedNodeIDs.contains($0.sourceNodeID) || removedNodeIDs.contains($0.targetNodeID) }
        masteryStates.removeAll { removedNodeIDs.contains($0.knowledgeNodeID) }
        knowledgeNodes.removeAll { removedNodeIDs.contains($0.id) }
    }

    func removeBatchSummaries(for activityIDs: Set<UUID>) {
        guard !activityIDs.isEmpty else { return }
        let links = (try? modelContext.fetch(FetchDescriptor<AnalysisBatchActivityLink>())) ?? []
        let matchingLinks = links.filter { activityIDs.contains($0.activityID) }
        guard !matchingLinks.isEmpty else { return }
        let affectedSummaryIDs = Set(matchingLinks.map(\.batchSummaryID))

        for summaryID in affectedSummaryIDs {
            let summaryLinks = links.filter { $0.batchSummaryID == summaryID }
            summaryLinks.forEach(modelContext.delete)

            var summaryDescriptor = FetchDescriptor<AnalysisBatchSummary>(
                predicate: #Predicate { $0.id == summaryID }
            )
            summaryDescriptor.fetchLimit = 1
            if let summary = try? modelContext.fetch(summaryDescriptor).first {
                modelContext.delete(summary)
            }
        }
    }

    func verifiedExistingNode(for analyzed: AnalyzedEvidence) -> KnowledgeNode? {
        if analyzed.matchConfidence >= 0.85,
           let matchedNodeID = analyzed.matchedNodeID,
           let matched = knowledgeNodes.first(where: { $0.id == matchedNodeID && !$0.isProvisional }) {
            return matched
        }
        return nil
    }

    func resolveNode(for analyzed: AnalyzedEvidence, suggestedDomain: String?) -> (node: KnowledgeNode, isNew: Bool) {
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

    func resolveNodeByName(_ name: String) -> KnowledgeNode? {
        knowledgeNodes.first(where: { $0.name.localizedStandardCompare(name) == .orderedSame })
    }
}
