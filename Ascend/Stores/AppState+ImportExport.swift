import Foundation
import SwiftData

extension AppState {
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
                    lifetimeXP: $0.lifetimeXP,
                    highestStageRawValue: $0.highestStageRawValue
                )
            },
            evidence: evidenceRecords.map {
                ExportedEvidence(
                    id: $0.id,
                    activityID: $0.activityID,
                    knowledgeNodeID: $0.knowledgeNodeID,
                    kind: $0.kind,
                    timestamp: $0.timestamp,
                    summary: $0.summary,
                    rationale: $0.rationale,
                    difficulty: $0.difficulty,
                    independence: $0.independence,
                    aiConfidence: $0.aiConfidence,
                    isVerified: $0.isVerified,
                    fingerprint: $0.fingerprint,
                    contentChangeHash: $0.contentChangeHash
                )
            },
            sources: sources.filter { $0.path != "demo://" }.map {
                ExportedSource(
                    id: $0.id,
                    name: $0.name,
                    kind: $0.kind,
                    path: $0.path,
                    isEnabled: $0.isEnabled,
                    analyzeWorkingTree: $0.analyzeWorkingTree,
                    analyzeMarkdown: $0.analyzeMarkdown,
                    analyzeCode: $0.analyzeCode,
                    authorFilter: $0.authorFilter,
                    remoteURLString: $0.remoteURLString,
                    ignorePatternsText: $0.ignorePatternsText,
                    lastScannedAt: $0.lastScannedAt,
                    lastCursor: $0.lastCursor,
                    lastUpstreamReference: $0.lastUpstreamReference
                )
            },
            endpoints: endpointProfiles.map {
                ExportedEndpoint(
                    id: $0.id,
                    name: $0.name,
                    baseURLString: $0.baseURLString,
                    selectedModelID: $0.selectedModelID,
                    cachedModelIDs: $0.cachedModelIDs,
                    isEnabled: $0.isEnabled
                )
            },
            challenges: challenges.map { challenge in
                let automation = challengeAutomationStates.first { state in state.challengeID == challenge.id }
                return ExportedChallenge(
                    id: challenge.id,
                    title: challenge.title,
                    description: challenge.challengeDescription,
                    status: challenge.status,
                    rewardXP: challenge.rewardXP,
                    estimatedMinutes: challenge.estimatedMinutes,
                    knowledgeNodeIDs: challenge.knowledgeNodeIDs,
                    requirements: challenge.requirements,
                    structuredRequirement: automation?.requirement,
                    acceptedAt: automation?.acceptedAt,
                    completedAt: challenge.completedAt
                )
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
            },
            realmAdvancements: realmAdvancementEvents.map {
                ExportedRealmAdvancement(
                    id: $0.id,
                    evidenceID: $0.evidenceID,
                    knowledgeNodeID: $0.knowledgeNodeID,
                    previousStage: $0.previousStage,
                    newStage: $0.newStage,
                    occurredAt: $0.occurredAt
                )
            },
            knowledgeEdges: knowledgeEdges.map {
                ExportedKnowledgeEdge(
                    id: $0.id,
                    sourceNodeID: $0.sourceNodeID,
                    targetNodeID: $0.targetNodeID,
                    relationRawValue: $0.relationRawValue,
                    confidence: $0.confidence
                )
            },
            memoryReviewEvents: memoryReviewEvents.map {
                ExportedMemoryReviewEvent(
                    id: $0.id,
                    knowledgeNodeID: $0.knowledgeNodeID,
                    evidenceID: $0.evidenceID,
                    canonicalKey: $0.canonicalKey,
                    gradeRawValue: $0.gradeRawValue,
                    reviewedAt: $0.reviewedAt,
                    sourceRawValue: $0.sourceRawValue
                )
            },
            scoreLedgerEntries: scoreLedgerEntries.map {
                ExportedScoreLedgerEntry(
                    id: $0.id,
                    evidenceID: $0.evidenceID,
                    knowledgeNodeID: $0.knowledgeNodeID,
                    timestamp: $0.timestamp,
                    previousComposite: $0.previousComposite,
                    newComposite: $0.newComposite,
                    xpAwarded: $0.xpAwarded,
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
            let highestStage = item.highestStageRawValue.flatMap(MasteryStage.init(rawValue:))
                ?? MasteryStage.stage(for: item.vector.composite)
            modelContext.insert(
                MasteryState(
                    knowledgeNodeID: item.knowledgeNodeID,
                    vector: item.vector,
                    confidence: item.confidence,
                    stabilityDays: item.stabilityDays,
                    lastEvidenceAt: item.lastEvidenceAt,
                    lifetimeXP: item.lifetimeXP,
                    highestStage: highestStage
                )
            )
        }
        for item in bundle.evidence {
            modelContext.insert(
                EvidenceRecord(
                    id: item.id,
                    activityID: item.activityID ?? UUID(),
                    knowledgeNodeID: item.knowledgeNodeID,
                    kind: item.kind,
                    timestamp: item.timestamp,
                    summary: item.summary,
                    rationale: item.rationale,
                    difficulty: item.difficulty ?? 1,
                    independence: item.independence ?? 1,
                    aiConfidence: item.aiConfidence ?? 0.8,
                    isVerified: item.isVerified,
                    fingerprint: item.fingerprint ?? "import-\(item.id.uuidString)",
                    contentChangeHash: item.contentChangeHash
                )
            )
        }
        for item in bundle.sources {
            let source = SourceConfiguration(
                id: item.id,
                name: item.name,
                kind: item.kind,
                path: item.path,
                isEnabled: item.isEnabled,
                analyzeWorkingTree: item.analyzeWorkingTree,
                analyzeMarkdown: item.analyzeMarkdown ?? true,
                analyzeCode: item.analyzeCode ?? true,
                authorFilter: item.authorFilter ?? "",
                remoteURLString: item.remoteURLString,
                ignorePatternsText: item.ignorePatternsText ?? ".git\nnode_modules\n.build\nbuild\ndist\nDerivedData"
            )
            source.lastScannedAt = item.lastScannedAt
            source.lastCursor = item.lastCursor
            source.lastUpstreamReference = item.lastUpstreamReference
            modelContext.insert(source)
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
            let challenge = Challenge(
                id: item.id,
                title: item.title,
                challengeDescription: item.description,
                estimatedMinutes: item.estimatedMinutes ?? 45,
                knowledgeNodeIDs: item.knowledgeNodeIDs ?? [],
                requirements: item.requirements ?? [],
                rewardXP: item.rewardXP,
                status: item.status
            )
            challenge.completedAt = item.completedAt
            modelContext.insert(challenge)
            if let requirement = item.structuredRequirement {
                modelContext.insert(
                    ChallengeAutomationState(
                        challengeID: challenge.id,
                        requirement: requirement,
                        acceptedAt: item.acceptedAt,
                        completedAt: item.completedAt
                    )
                )
            }
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
        for item in bundle.realmAdvancements ?? [] {
            modelContext.insert(
                RealmAdvancementEvent(
                    id: item.id,
                    evidenceID: item.evidenceID,
                    knowledgeNodeID: item.knowledgeNodeID,
                    previousStage: item.previousStage,
                    newStage: item.newStage,
                    occurredAt: item.occurredAt
                )
            )
        }
        for item in bundle.knowledgeEdges ?? [] {
            modelContext.insert(
                KnowledgeEdge(
                    id: item.id,
                    sourceNodeID: item.sourceNodeID,
                    targetNodeID: item.targetNodeID,
                    relationRawValue: item.relationRawValue,
                    confidence: item.confidence
                )
            )
        }
        for item in bundle.memoryReviewEvents ?? [] {
            modelContext.insert(
                MemoryReviewEvent(
                    id: item.id,
                    knowledgeNodeID: item.knowledgeNodeID,
                    evidenceID: item.evidenceID,
                    canonicalKey: item.canonicalKey,
                    grade: MemoryReviewGrade(rawValue: item.gradeRawValue) ?? .good,
                    reviewedAt: item.reviewedAt,
                    source: item.sourceRawValue
                )
            )
        }
        for item in bundle.scoreLedgerEntries ?? [] {
            modelContext.insert(
                ScoreLedgerEntry(
                    id: item.id,
                    evidenceID: item.evidenceID,
                    knowledgeNodeID: item.knowledgeNodeID,
                    timestamp: item.timestamp,
                    previousComposite: item.previousComposite,
                    newComposite: item.newComposite,
                    xpAwarded: item.xpAwarded,
                    reason: item.reason
                )
            )
        }
        try modelContext.save()
        load()
        let affectedMemoryNodeIDs = Set(memoryReviewEvents.map(\.knowledgeNodeID))
        for nodeID in affectedMemoryNodeIDs {
            replayMemory(nodeID: nodeID)
        }
        if !affectedMemoryNodeIDs.isEmpty {
            try modelContext.save()
            load()
        }
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
        try modelContext.save()
        setActiveEndpoint(nil)
        load()
    }

    func cleanupLegacyDemoDataIfNeeded() {
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

    func cleanupUnverifiedChallengeCompletionIfNeeded() {
        let migrationKey = "didResetUnverifiedChallengeCompletions.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        challenges.filter { $0.status == "completed" }.forEach { $0.status = "in_progress" }
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    func cleanupDuplicateActivityEventsIfNeeded() {
        guard let allEvents = try? modelContext.fetch(FetchDescriptor<ActivityEvent>()) else { return }

        // 只清理完全相同的采集事件；同一路径后续产生的新指纹必须保留。
        let grouped = Dictionary(grouping: allEvents.filter { !$0.fingerprint.isEmpty }) { event in
            "\(event.sourceID.uuidString):\(event.fingerprint)"
        }

        var deletedCount = 0
        for (_, events) in grouped where events.count > 1 {
            let sorted = events.sorted {
                if $0.isProcessed != $1.isProcessed { return $0.isProcessed && !$1.isProcessed }
                return $0.timestamp < $1.timestamp
            }
            for duplicate in sorted.dropFirst() {
                modelContext.delete(duplicate)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try? modelContext.save()
            AppLogger.collector.info("Cleaned up \(deletedCount) duplicate activity events")
        }
    }

    func migrateLegacyRemoteGitSourcesIfNeeded() {
        let legacySources = sources.filter { $0.kind == .remoteGitMarkdown }
        guard !legacySources.isEmpty else { return }
        for source in legacySources {
            source.kindRawValue = SourceKind.remoteGitRepository.rawValue
            source.analyzeMarkdown = true
            source.analyzeCode = true
        }
        try? modelContext.save()
    }

    func reconcileActiveEndpointSelection() {
        if let activeEndpointID,
           endpointProfiles.contains(where: { $0.id == activeEndpointID && $0.isEnabled }) {
            return
        }
        let fallback = endpointProfiles.first(where: { $0.isEnabled && !$0.selectedModelID.isEmpty })
            ?? endpointProfiles.first(where: \.isEnabled)
        setActiveEndpoint(fallback?.id)
    }
}
