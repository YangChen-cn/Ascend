import Foundation
import SwiftData
import UserNotifications

extension AppState {
    func startAutomation() async {
        guard !automationStarted else { return }
        automationStarted = true
        runTriggerEngine()
        await synchronizeCollectionScheduler()
        await evaluateAutomaticAnalysis()
        await automationTickScheduler.start(interval: .seconds(10 * 60)) { [weak self] in
            await self?.runAutomationTick()
        }
    }

    func runAutomationTick(now: Date = .now) async {
        runTriggerEngine(now: now)
        await evaluateAutomaticAnalysis(now: now)
    }

    func restartCollectionSchedulerIfNeeded() {
        guard automationStarted else { return }
        Task { [weak self] in
            await self?.synchronizeCollectionScheduler(restartsRunningScheduler: true)
        }
    }

    func synchronizeCollectionScheduler(restartsRunningScheduler: Bool = false) async {
        if restartsRunningScheduler {
            await collectionScheduler.stop()
        }
        guard isCollecting else {
            await collectionScheduler.stop()
            isCollectionSchedulerRunning = false
            return
        }

        await collectionScheduler.start(
            interval: .seconds(collectionIntervalMinutes * 60)
        ) { [weak self] in
            await self?.runScheduledCollectionCycle()
        }
        isCollectionSchedulerRunning = await collectionScheduler.isRunning
    }

    func runScheduledCollectionCycle() async {
        do {
            try await scanSources()
            await evaluateAutomaticAnalysis()
        } catch {
            AppLogger.collector.error("Scheduled source scan failed: \(error.localizedDescription, privacy: .public)")
            statusMessage = "自动采集失败：\(error.localizedDescription)"
        }
    }

    func evaluateAutomaticAnalysis(now: Date = .now) async {
        let lastRunAt = automationDefaults.object(forKey: AutomationPreferences.lastAutomaticAnalysisAtKey) as? Date
        let succeeded = await analysisScheduler.runIfNeeded(
            policy: automaticAnalysisPolicy,
            pendingCount: pendingActivityCount,
            threshold: automaticAnalysisThreshold,
            dailyHour: automaticDailyAnalysisHour,
            dailyMinute: automaticDailyAnalysisMinute,
            lastRunAt: lastRunAt,
            now: now
        ) { [weak self] in
            guard let self else { return false }
            return await self.analyzeActivities(
                endpointOverride: nil,
                modelOverride: nil,
                targetActivityIDs: nil,
                overwritesExistingResults: false,
                performsPreflightScan: false
            )
        }
        if succeeded {
            automationDefaults.set(now, forKey: AutomationPreferences.lastAutomaticAnalysisAtKey)
        }
    }

    @discardableResult
    func runTriggerEngine(now: Date = .now) -> Int {
        let evidenceSnapshots = evidenceRecords.map {
            ChallengeEvidenceSnapshot(
                id: $0.id,
                knowledgeNodeID: $0.knowledgeNodeID,
                kind: $0.kind,
                timestamp: $0.timestamp,
                independence: $0.independence,
                confidence: $0.aiConfidence,
                isVerified: $0.isVerified,
                canonicalKey: EvidenceCanonicalIdentity.key(
                    contentChangeHash: $0.contentChangeHash,
                    knowledgeNodeID: $0.knowledgeNodeID,
                    fingerprint: $0.fingerprint,
                    evidenceID: $0.id
                )
            )
        }
        var memoryProjectionChanged = false
        let memorySnapshots = memoryStates.map { state in
            let retrievability = (currentRetention(for: state.knowledgeNodeID, now: now) ?? state.retrievability * 100) / 100
            if abs(state.retrievability - retrievability) > 0.0001 {
                memoryProjectionChanged = true
            }
            state.retrievability = retrievability
            state.updatedAt = now
            return MemoryTriggerSnapshot(
                knowledgeNodeID: state.knowledgeNodeID,
                retrievability: retrievability,
                nextReviewAt: state.nextReviewAt,
                reps: state.reps
            )
        }
        let planSnapshots = reviewPlans.map {
            ReviewPlanTriggerSnapshot(
                id: $0.id,
                knowledgeNodeID: $0.knowledgeNodeID,
                createdAt: $0.createdAt,
                scheduledAt: $0.scheduledAt,
                status: $0.status
            )
        }

        var changeCount = 0
        for action in triggerEngine.reviewPlanActions(
            memory: memorySnapshots,
            plans: planSnapshots,
            evidence: evidenceSnapshots,
            memoryReviewCanonicalKeys: Set(memoryReviewEvents.map(\.canonicalKey)),
            now: now
        ) {
            switch action {
            case let .markDue(planID):
                guard let plan = reviewPlans.first(where: { $0.id == planID }), plan.status == "scheduled" else { continue }
                plan.status = "due"
                changeCount += 1
            case let .complete(planID, _):
                guard let plan = reviewPlans.first(where: { $0.id == planID }), plan.status != "completed" else { continue }
                plan.status = "completed"
                changeCount += 1
            case let .create(nodeID, scheduledAt, reason):
                let plan = ReviewPlan(
                    knowledgeNodeID: nodeID,
                    createdAt: now,
                    scheduledAt: scheduledAt,
                    reason: reason,
                    status: scheduledAt <= now ? "due" : "scheduled"
                )
                modelContext.insert(plan)
                reviewPlans.append(plan)
                changeCount += 1
            }
        }

        let existingRealmEvidenceIDs = Set(realmAdvancementEvents.map(\.evidenceID))
        for entry in scoreLedgerEntries where !existingRealmEvidenceIDs.contains(entry.evidenceID) {
            let previous = MasteryStage.stage(for: entry.previousComposite)
            let next = MasteryStage.stage(for: entry.newComposite)
            guard next.level > previous.level else { continue }
            let event = RealmAdvancementEvent(
                evidenceID: entry.evidenceID,
                knowledgeNodeID: entry.knowledgeNodeID,
                previousStage: previous,
                newStage: next,
                occurredAt: entry.timestamp
            )
            modelContext.insert(event)
            realmAdvancementEvents.append(event)
            changeCount += 1
        }

        let currentMastery = Dictionary(uniqueKeysWithValues: masteryStates.map { state in
            (state.knowledgeNodeID, readiness(for: state.knowledgeNodeID, now: now)?.currentComposite ?? 0)
        })
        let automationByChallengeID = Dictionary(uniqueKeysWithValues: challengeAutomationStates.map { ($0.challengeID, $0) })
        for challenge in challenges where challenge.status == "in_progress" {
            guard let automation = automationByChallengeID[challenge.id],
                  let acceptedAt = automation.acceptedAt else { continue }
            let evaluation = challengeEvaluator.evaluate(
                targetNodeIDs: Set(challenge.knowledgeNodeIDs),
                requirement: automation.requirement,
                acceptedAt: acceptedAt,
                currentMasteryByNodeID: currentMastery,
                evidence: evidenceSnapshots
            )
            automation.matchedEvidenceIDs = evaluation.matchedEvidenceIDs
            if evaluation.isCompleted {
                challenge.status = "completed"
                challenge.completedAt = now
                automation.completedAt = now
                changeCount += 1
            }
        }

        let receiptKeys = Set(automationReceipts.map(\.key))
        let plansToNotify = reviewPlans.filter {
            $0.status == "due" && !receiptKeys.contains("review-due-notification:\($0.id.uuidString)")
        }
        for plan in plansToNotify {
            let planID = plan.id
            let knowledgeNodeID = plan.knowledgeNodeID
            let receipt = AutomationReceipt(
                key: "review-due-notification:\(planID.uuidString)",
                kind: "reviewDueNotification",
                createdAt: now
            )
            modelContext.insert(receipt)
            automationReceipts.append(receipt)
            changeCount += 1
            guard let knowledgeName = node(for: knowledgeNodeID)?.name else { continue }
            let scheduler = digestScheduler
            Task {
                do {
                    try await scheduler.sendReviewDueNotification(
                        planID: planID,
                        knowledgeName: knowledgeName
                    )
                } catch {
                    AppLogger.app.error("Review notification failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        if changeCount > 0 || memoryProjectionChanged {
            try? modelContext.save()
            refreshDerivedState()
        }
        return changeCount
    }

    func upsertDailyDigest(
        date: Date,
        batchSummaries: [String],
        calendar: Calendar = .current
    ) throws -> DailyDigest {
        let day = calendar.startOfDay(for: date)
        let existing = digests.first { calendar.isDate($0.date, inSameDayAs: day) }
        let digest = existing ?? DailyDigest(date: day, summary: "", xpEarned: 0)

        let dayLedger = scoreLedgerEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
        let dayReviewPlans = reviewPlans.filter { calendar.isDate($0.scheduledAt, inSameDayAs: day) }
        let dayChallenges = challenges.filter {
            guard let completedAt = $0.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: day)
        }

        let allLinks = (try? modelContext.fetch(FetchDescriptor<AnalysisBatchActivityLink>())) ?? []
        let matchingLinks = allLinks.filter { calendar.isDate($0.activityDate, inSameDayAs: day) }
        let batchSummaryIDs = Set(matchingLinks.map(\.batchSummaryID))

        var persistedSummaries: [String] = []
        if !batchSummaryIDs.isEmpty {
            let allBatchSummaries = (try? modelContext.fetch(FetchDescriptor<AnalysisBatchSummary>())) ?? []
            persistedSummaries = allBatchSummaries.filter { batchSummaryIDs.contains($0.id) }.map(\.summary)
        }

        let activityIDs = Set(matchingLinks.map(\.activityID))
        let dayActivitySummary = try activitySummary(for: activityIDs)
        let combinedBatchSummaries = uniqueDigestSummaryParts(batchSummaries + persistedSummaries + (dayActivitySummary.map { [$0] } ?? []))

        let currentRetentionByNodeID = Dictionary(uniqueKeysWithValues: memoryStates.compactMap { memory in
            currentRetention(for: memory.knowledgeNodeID).map { (memory.knowledgeNodeID, $0) }
        })
        let dayForgetting = analyticsEngine.computeForgettingProjections(
            nodes: knowledgeNodes,
            masteryStates: masteryStates,
            currentRetentionByNodeID: currentRetentionByNodeID
        )

        let snapshot = digestAggregator.aggregate(
            date: day,
            batchSummaries: combinedBatchSummaries,
            nodes: knowledgeNodes,
            ledgerEntries: dayLedger,
            forgetting: dayForgetting,
            dueReviewPlans: dayReviewPlans.filter { $0.status == "due" },
            completedChallenges: dayChallenges,
            calendar: calendar
        )

        digest.summary = snapshot.summary
        digest.xpEarned = snapshot.xpEarned
        digest.improvedNodeIDsJSON = Self.encodeUUIDs(snapshot.improvedNodeIDs)
        digest.forgettingNodeIDsJSON = Self.encodeUUIDs(snapshot.forgettingNodeIDs)
        digest.generatedAt = Date.now

        if existing == nil {
            modelContext.insert(digest)
            digests.insert(digest, at: 0)
        }
        digests.sort { $0.date > $1.date }
        try modelContext.save()
        return digest
    }

    func activitySummary(for activityIDs: Set<UUID>) throws -> String? {
        guard !activityIDs.isEmpty else { return nil }
        let activities = try fetchActivities(ids: activityIDs)
        let titles = activities.map(\.title).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !titles.isEmpty else { return nil }
        let uniqueTitles = titles.reduce(into: [String]()) { result, title in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !result.contains(trimmed) {
                result.append(trimmed)
            }
        }
        return uniqueTitles.joined(separator: "、")
    }

    func uniqueDigestSummaryParts(_ parts: [String]) -> [String] {
        parts.reduce(into: [String]()) { result, part in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if !result.contains(where: { $0.localizedStandardCompare(trimmed) == .orderedSame }) {
                result.append(trimmed)
            }
        }
    }

    nonisolated static func encodeUUIDs(_ ids: [UUID]) -> String {
        (try? String(data: JSONEncoder().encode(ids), encoding: .utf8)) ?? "[]"
    }

    func configureNotifications(hour: Int, minute: Int) async throws {
        try await digestScheduler.scheduleDailyDigest(hour: hour, minute: minute)
        statusMessage = "已更新每日简报通知时间为 \(String(format: "%02d:%02d", hour, minute))"
    }

    func checkNotificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await digestScheduler.authorizationStatus()
    }

    func sendTestNotification() async throws {
        try await digestScheduler.sendDigestReadyNotification(summary: "这是一条来自知境录的测试通知。系统通知管道工作正常！")
    }

    func scheduleReview(
        for nodeID: UUID,
        scheduledAt: Date,
        reason: String
    ) throws {
        guard node(for: nodeID) != nil else { throw AppStateError.missingKnowledgeNode }
        if let existing = reviewPlans.first(where: {
            $0.knowledgeNodeID == nodeID &&
                ($0.status == "scheduled" || $0.status == "due")
        }) {
            statusMessage = "“\(node(for: nodeID)?.name ?? "该知识点")”已有有效复习计划：\(existing.scheduledAt.formatted(date: .abbreviated, time: .shortened))"
            return
        }
        let plan = ReviewPlan(
            knowledgeNodeID: nodeID,
            scheduledAt: scheduledAt,
            reason: reason
        )
        modelContext.insert(plan)
        try modelContext.save()
        reviewPlans.insert(plan, at: 0)
        runTriggerEngine()
        statusMessage = "已安排真实复习计划：\(scheduledAt.formatted(date: .abbreviated, time: .shortened))"
    }

    func reviewPlans(for nodeID: UUID) -> [ReviewPlan] {
        reviewPlans
            .filter { $0.knowledgeNodeID == nodeID }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    func cancelReviewPlan(_ plan: ReviewPlan) {
        guard plan.status == "scheduled" || plan.status == "due" else { return }
        plan.status = "cancelled"
        try? modelContext.save()
        statusMessage = "已取消复习计划"
    }

    func updateChallengeStatus(_ challenge: Challenge, status: String) {
        guard status != "completed" else {
            statusMessage = "挑战完成必须由后续真实学习证据验证，不能手动结算"
            return
        }
        challenge.status = status
        if status == "in_progress" {
            let automation = challengeAutomationStates.first(where: { $0.challengeID == challenge.id }) ?? {
                let created = ChallengeAutomationState(
                    challengeID: challenge.id,
                    requirement: ChallengeRequirement()
                )
                modelContext.insert(created)
                challengeAutomationStates.append(created)
                return created
            }()
            if automation.acceptedAt == nil { automation.acceptedAt = .now }
            statusMessage = "已接取挑战“\(challenge.title)”，开始实践吧！"
        } else {
            statusMessage = "已更新挑战状态"
        }
        try? modelContext.save()
        runTriggerEngine()
    }

    func updateSnapshots() {
        let currentRetentionByNodeID = Dictionary(uniqueKeysWithValues: memoryStates.compactMap { memory in
            currentRetention(for: memory.knowledgeNodeID).map { (memory.knowledgeNodeID, $0) }
        })
        domainProgress = analyticsEngine.computeDomainProgress(
            nodes: knowledgeNodes,
            masteryStates: masteryStates,
            currentRetentionByNodeID: currentRetentionByNodeID
        )
        todayMasteryChanges = analyticsEngine.computeTodayMasteryChanges(nodes: knowledgeNodes, ledgerEntries: scoreLedgerEntries)
        todayXPGains = analyticsEngine.computeTodayXPGains(evidenceRecords: evidenceRecords, ledgerEntries: scoreLedgerEntries)
        forgettingProjections = analyticsEngine.computeForgettingProjections(
            nodes: knowledgeNodes,
            masteryStates: masteryStates,
            currentRetentionByNodeID: currentRetentionByNodeID
        )
        let compositeScores = Dictionary(uniqueKeysWithValues: masteryStates.map { ($0.knowledgeNodeID, $0.vector.composite) })
        let nodeNamesByID = Dictionary(uniqueKeysWithValues: knowledgeNodes.map { ($0.id, $0.name) })
        let readinessProvider = TopologyReadinessProvider(
            engine: topologyEngine,
            edges: knowledgeEdges,
            masteryByNodeID: compositeScores,
            nodeNamesByID: nodeNamesByID
        )
        learningRecommendations = recommendationEngine.recommendations(
            knowledge: recommendationSnapshots(currentRetentionByNodeID: currentRetentionByNodeID, compositeScores: compositeScores),
            challenges: challenges.map {
                RecommendationChallengeSnapshot(
                    id: $0.id,
                    title: $0.title,
                    knowledgeNodeIDs: Set($0.knowledgeNodeIDs),
                    status: $0.status
                )
            },
            now: .now,
            prerequisiteProvider: readinessProvider
        )
    }

    func recommendationSnapshots(
        currentRetentionByNodeID: [UUID: Double],
        compositeScores: [UUID: Double]? = nil,
        now: Date = .now
    ) -> [RecommendationKnowledgeSnapshot] {
        let scores = compositeScores ?? Dictionary(uniqueKeysWithValues: masteryStates.map { ($0.knowledgeNodeID, $0.vector.composite) })
        let recentStart = now.addingTimeInterval(-7 * 86_400)
        let activePlansByNodeID = reviewPlans
            .filter { $0.status == "scheduled" || $0.status == "due" }
            .reduce(into: [UUID: ReviewPlan]()) { result, plan in
                if let existing = result[plan.knowledgeNodeID], existing.scheduledAt <= plan.scheduledAt { return }
                result[plan.knowledgeNodeID] = plan
            }
        return knowledgeNodes.compactMap { node in
            guard let mastery = masteryByNodeID[node.id] else { return nil }
            let evidence = evidenceByNodeID[node.id, default: []]
            let plan = activePlansByNodeID[node.id]
            let isReady = topologyEngine.isReadyToLearn(for: node.id, edges: knowledgeEdges, masteryByNodeID: scores)
            let satisfiedPrereqs = topologyEngine.prerequisiteNodeIDs(for: node.id, in: knowledgeEdges)
                .filter { (scores[$0] ?? 0) >= topologyEngine.prerequisiteThreshold }
            return RecommendationKnowledgeSnapshot(
                id: node.id,
                name: node.name,
                mastery: mastery.vector,
                retrievability: currentRetentionByNodeID[node.id].map { $0 / 100 },
                activeReviewPlanID: plan?.id,
                reviewScheduledAt: plan?.scheduledAt,
                recentEvidenceCount: evidence.count { $0.isVerified && $0.timestamp >= recentStart },
                lastEvidenceAt: evidence.filter(\.isVerified).map(\.timestamp).max(),
                isReadyToLearn: isReady,
                satisfiedPrerequisitesCount: satisfiedPrereqs.count
            )
        }
    }
}
