import Foundation
import SwiftData

extension AppState {
    @discardableResult
    func applyScoring(
        evidence: EvidenceRecord,
        node: KnowledgeNode,
        memoryGradeOverride: MemoryReviewGrade? = nil
    ) -> Int {
        let existingVerified = evidenceRecords(for: node.id).filter { $0.id != evidence.id && $0.isVerified }
        let scoringKey = evidenceScoringKey(evidence)
        let isDuplicateProvenance = !scoringKey.isEmpty && existingVerified.contains {
            evidenceScoringKey($0) == scoringKey
        }
        if isDuplicateProvenance {
            AppLogger.scoring.info("Skipping scoring for duplicate provenance evidence on node \(node.name, privacy: .public)")
            return 0
        }

        let state = masteryByNodeID[node.id] ?? {
            let created = MasteryState(knowledgeNodeID: node.id)
            modelContext.insert(created)
            masteryStates.append(created)
            masteryByNodeID[node.id] = created
            return created
        }()
        let previous = state.vector
        var updated = previous
        if memoryGradeOverride != .again {
            let result = scoringEngine.apply(
                ScoringInput(
                    current: previous,
                    kind: evidence.kind,
                    difficulty: evidence.difficulty,
                    independence: evidence.independence,
                    confidence: evidence.aiConfidence,
                    stabilityDays: state.stabilityDays,
                    lastEvidenceAt: state.lastEvidenceAt,
                    timestamp: evidence.timestamp
                )
            )
            updated = result.updated
        }

        let inferredGrade = MemoryReviewEligibility.inferredGrade(
            for: MemoryReviewEvidenceSnapshot(
                kind: evidence.kind,
                confidence: evidence.aiConfidence,
                independence: evidence.independence,
                isVerified: evidence.isVerified
            )
        )
        let memoryGrade = memoryGradeOverride ?? inferredGrade
        if let memoryGrade,
           registerMemoryReview(evidence: evidence, grade: memoryGrade, source: memoryGradeOverride == nil ? "verifiedEvidence" : "explicitGrade"),
           memoryGrade != .again,
           let reviewedRetention = currentRetention(for: node.id, now: evidence.timestamp) {
            updated.retention = max(updated.retention, reviewedRetention)
        }

        state.vector = updated.clamped()
        state.lastEvidenceAt = evidence.timestamp
        let xpAwarded = Int((max(0, state.composite - previous.composite) * 10).rounded())
        state.lifetimeXP += xpAwarded
        state.confidence = confidence(for: node.id)
        let newStage = MasteryStage.stage(for: state.composite)
        if newStage.level > (MasteryStage(rawValue: state.highestStageRawValue)?.level ?? 1) {
            state.highestStageRawValue = newStage.rawValue
        }
        let ledgerEntry = ScoreLedgerEntry(
            evidenceID: evidence.id,
            knowledgeNodeID: node.id,
            timestamp: evidence.timestamp,
            previousComposite: previous.composite,
            newComposite: state.composite,
            xpAwarded: xpAwarded,
            reason: evidence.rationale
        )
        modelContext.insert(ledgerEntry)
        scoreLedgerEntries.insert(ledgerEntry, at: 0)
        ledgerByNodeID[node.id, default: []].append(ledgerEntry)
        ledgerByNodeID[node.id]?.sort { $0.timestamp < $1.timestamp }
        return xpAwarded
    }

    @discardableResult
    func registerMemoryReview(
        evidence: EvidenceRecord,
        grade: MemoryReviewGrade,
        source: String
    ) -> Bool {
        let canonicalKey = evidenceScoringKey(evidence)
        guard !memoryReviewEvents.contains(where: {
            $0.knowledgeNodeID == evidence.knowledgeNodeID && $0.canonicalKey == canonicalKey
        }) else { return false }
        let event = MemoryReviewEvent(
            knowledgeNodeID: evidence.knowledgeNodeID,
            evidenceID: evidence.id,
            canonicalKey: canonicalKey,
            grade: grade,
            reviewedAt: evidence.timestamp,
            source: source
        )
        modelContext.insert(event)
        memoryReviewEvents.append(event)
        replayMemory(nodeID: evidence.knowledgeNodeID)
        return true
    }

    func replayMastery(nodeID: UUID, evidence: [EvidenceRecord]) {
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

        var seenScoringKeys = Set<String>()
        let memoryGradeByEvidenceID = Dictionary(
            uniqueKeysWithValues: memoryReviewEvents.compactMap { event in
                event.evidenceID.map { ($0, event.grade) }
            }
        )
        for item in evidence.filter(\.isVerified).sorted(by: { $0.timestamp < $1.timestamp }) {
            let scoringKey = evidenceScoringKey(item)
            if !scoringKey.isEmpty && seenScoringKeys.contains(scoringKey) {
                continue
            }
            if !scoringKey.isEmpty {
                seenScoringKeys.insert(scoringKey)
            }
            let previous = state.vector
            let grade = memoryGradeByEvidenceID[item.id]
            var updated = previous
            if grade != .again {
                updated = scoringEngine.apply(
                    ScoringInput(
                        current: previous,
                        kind: item.kind,
                        difficulty: item.difficulty,
                        independence: item.independence,
                        confidence: item.aiConfidence,
                        stabilityDays: state.stabilityDays,
                        lastEvidenceAt: state.lastEvidenceAt,
                        timestamp: item.timestamp
                    )
                ).updated
            }
            if let grade, grade != .again {
                updated.retention = max(updated.retention, 100)
            }
            state.vector = updated.clamped()
            state.lastEvidenceAt = item.timestamp
            let xpAwarded = Int((max(0, state.composite - previous.composite) * 10).rounded())
            state.lifetimeXP += xpAwarded
            state.highestStageRawValue = MasteryStage.stage(for: state.composite).rawValue
            modelContext.insert(
                ScoreLedgerEntry(
                    evidenceID: item.id,
                    knowledgeNodeID: nodeID,
                    timestamp: item.timestamp,
                    previousComposite: previous.composite,
                    newComposite: state.composite,
                    xpAwarded: xpAwarded,
                    reason: item.rationale
                )
            )
        }
        state.confidence = confidence(for: nodeID, evidence: evidence)
        replayMemory(nodeID: nodeID)
        if memoryReviewEvents.contains(where: { $0.knowledgeNodeID == nodeID && $0.grade != .again }) {
            state.retention = max(state.retention, currentRetention(for: nodeID, now: state.lastEvidenceAt ?? .now) ?? 0)
        }
    }

    func replayMemory(nodeID: UUID) {
        let events = memoryReviewEvents
            .filter { $0.knowledgeNodeID == nodeID }
            .sorted {
                $0.reviewedAt == $1.reviewedAt
                    ? $0.canonicalKey < $1.canonicalKey
                    : $0.reviewedAt < $1.reviewedAt
            }
        guard !events.isEmpty else {
            if let existing = memoryByNodeID[nodeID] {
                modelContext.delete(existing)
                memoryStates.removeAll { $0.id == existing.id }
                memoryByNodeID.removeValue(forKey: nodeID)
            }
            return
        }

        do {
            var schedulingState: MemorySchedulingState?
            var finalResult: MemorySchedulingResult?
            for event in events {
                let result = try memoryScheduler.review(
                    state: schedulingState,
                    grade: event.grade,
                    at: event.reviewedAt,
                    desiredRetention: MemorySchedulingPreferences.desiredRetention
                )
                schedulingState = result.state
                finalResult = result
            }
            guard let finalResult, let lastDate = events.last?.reviewedAt else { return }
            let memory = memoryByNodeID[nodeID] ?? {
                let created = MemoryState(knowledgeNodeID: nodeID)
                modelContext.insert(created)
                memoryStates.append(created)
                memoryByNodeID[nodeID] = created
                return created
            }()
            memory.update(from: finalResult, at: lastDate)
        } catch {
            AppLogger.scoring.error("FSRS replay failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func recordReviewGrade(
        for nodeID: UUID,
        grade: MemoryReviewGrade,
        at date: Date = .now
    ) throws {
        guard let node = node(for: nodeID) else { throw AppStateError.missingKnowledgeNode }
        let activity = ActivityEvent(
            sourceID: UUID(),
            sourceKind: .manual,
            timestamp: date,
            fingerprint: "manual-review-\(UUID().uuidString)",
            title: "复习 · \(node.name)",
            sourceLocator: "manual-review/\(nodeID.uuidString)",
            summary: "用户复习反馈：\(grade.title)",
            excerpt: ""
        )
        activity.isProcessed = true
        let evidence = EvidenceRecord(
            activityID: activity.id,
            knowledgeNodeID: nodeID,
            kind: .review,
            timestamp: date,
            summary: "复习结果：\(grade.title)",
            rationale: "用户明确提交 FSRS 复习等级“\(grade.title)”",
            difficulty: 1,
            independence: 1,
            aiConfidence: 1,
            isVerified: true,
            fingerprint: activity.fingerprint + "-" + nodeID.uuidString
        )
        modelContext.insert(activity)
        modelContext.insert(evidence)
        activityEvents.insert(activity, at: 0)
        evidenceRecords.insert(evidence, at: 0)
        evidenceByID[evidence.id] = evidence
        evidenceByNodeID[nodeID, default: []].insert(evidence, at: 0)
        let xp = applyScoring(evidence: evidence, node: node, memoryGradeOverride: grade)
        try modelContext.save()
        refreshDerivedState()
        runTriggerEngine(now: date)
        statusMessage = "已记录“\(node.name)”复习：\(grade.title)\(xp > 0 ? "，获得 \(xp) XP" : "")"
    }

    func evidenceScoringKey(_ evidence: EvidenceRecord) -> String {
        EvidenceCanonicalIdentity.key(
            contentChangeHash: evidence.contentChangeHash,
            knowledgeNodeID: evidence.knowledgeNodeID,
            fingerprint: evidence.fingerprint,
            evidenceID: evidence.id
        )
    }

    func confidence(for nodeID: UUID) -> Double {
        confidence(for: nodeID, evidence: evidenceRecords)
    }

    func confidence(for nodeID: UUID, evidence: [EvidenceRecord]) -> Double {
        let evidence = evidence.filter { $0.knowledgeNodeID == nodeID && $0.isVerified }
        let weighted = evidence.reduce(0.0) { result, item in
            let ageDays = max(0, Date.now.timeIntervalSince(item.timestamp) / 86_400)
            return result + item.aiConfidence * exp(-ageDays / 90)
        }
        return 100 * (1 - exp(-weighted / 6))
    }

    func icon(for kind: EvidenceKind) -> String {
        switch kind {
        case .exposure: "eye"
        case .explanation: "book"
        case .exercise: "checklist"
        case .project: "chevron.left.forwardslash.chevron.right"
        case .review: "arrow.clockwise"
        case .independentSolve: "target"
        }
    }
}
