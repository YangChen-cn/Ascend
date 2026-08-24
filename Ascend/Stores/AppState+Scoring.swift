import Foundation

extension AppState {
    @discardableResult
    func registerMemoryReview(
        evidence: EvidenceRecord,
        grade: MemoryReviewGrade,
        source: String
    ) -> Bool {
        guard evidence.verificationLevel.isDirectPerformance,
              evidence.assistanceMode == .declaredUnassisted else { return false }
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
        _ = (nodeID, grade, date)
        throw AppStateError.reviewRequiresAssessment
    }

    func evidenceScoringKey(_ evidence: EvidenceRecord) -> String {
        EvidenceCanonicalIdentity.key(
            contentChangeHash: evidence.contentChangeHash,
            knowledgeNodeID: evidence.knowledgeNodeID,
            fingerprint: evidence.fingerprint,
            evidenceID: evidence.id
        )
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

    @discardableResult
    func applyArtifactEvidence(_ evidence: EvidenceRecord) -> Int {
        guard evidence.origin == .artifact || evidence.verificationLevel == .artifactCandidate else { return 0 }
        let nodeID = evidence.knowledgeNodeID

        if let hash = evidence.contentChangeHash, !hash.isEmpty {
            let alreadyScored = evidenceRecords.contains {
                $0.id != evidence.id &&
                $0.knowledgeNodeID == nodeID &&
                $0.isVerified &&
                $0.contentChangeHash == hash
            }
            if alreadyScored { return 0 }
        }

        let state = masteryByNodeID[nodeID] ?? {
            let created = MasteryState(knowledgeNodeID: nodeID)
            modelContext.insert(created)
            masteryStates.append(created)
            masteryByNodeID[nodeID] = created
            return created
        }()

        let previousComposite = state.vector.composite
        let scoringEngine = ScoringEngine()
        let input = ScoringInput(
            current: state.vector,
            kind: evidence.kind,
            difficulty: evidence.difficulty,
            independence: evidence.independence,
            confidence: evidence.aiConfidence,
            stabilityDays: 0,
            lastEvidenceAt: state.lastEvidenceAt,
            timestamp: evidence.timestamp
        )
        let result = scoringEngine.apply(input)
        state.vector = result.updated
        state.lastEvidenceAt = evidence.timestamp

        // Artifact 弱证据推动初窥 → 入门 → 通晓（最高成长至通晓门槛 59.9）
        let compositeForXP = min(59.9, state.vector.composite)
        let xpGain = Int((max(0, compositeForXP - state.peakComposite) * 10).rounded())
        if xpGain > 0 {
            state.peakComposite = max(state.peakComposite, compositeForXP)
            state.lifetimeXP += xpGain

            let ledger = ScoreLedgerEntry(
                evidenceID: evidence.id,
                knowledgeNodeID: nodeID,
                timestamp: evidence.timestamp,
                previousComposite: previousComposite,
                newComposite: compositeForXP,
                xpAwarded: xpGain,
                reason: "研习实据沉淀 · \(evidence.kind.title)"
            )
            modelContext.insert(ledger)
            scoreLedgerEntries.insert(ledger, at: 0)
            ledgerByNodeID[nodeID, default: []].append(ledger)
        }

        let rawStage = MasteryStage.stage(for: compositeForXP)
        let eligibleStage = rawStage.level > MasteryStage.proficient.level ? MasteryStage.proficient : rawStage
        if eligibleStage.level > state.highestStage.level {
            state.highestStageRawValue = eligibleStage.rawValue
        }

        return xpGain
    }

    func replayArtifactEvidence(nodeID: UUID) {
        guard let state = masteryByNodeID[nodeID] else { return }
        let nodeEvidences = (evidenceByNodeID[nodeID] ?? [])
            .filter { $0.origin == .artifact || $0.verificationLevel == .artifactCandidate }
            .sorted { $0.timestamp < $1.timestamp }

        var vector = MasteryVector.zero
        let scoringEngine = ScoringEngine()
        var peak: Double = 0
        var totalXP = 0

        for ev in nodeEvidences {
            let input = ScoringInput(
                current: vector,
                kind: ev.kind,
                difficulty: ev.difficulty,
                independence: ev.independence,
                confidence: ev.aiConfidence,
                stabilityDays: 0,
                lastEvidenceAt: ev.timestamp,
                timestamp: ev.timestamp
            )
            let res = scoringEngine.apply(input)
            vector = res.updated
            let comp = min(59.9, vector.composite)
            let gain = Int((max(0, comp - peak) * 10).rounded())
            if gain > 0 {
                peak = max(peak, comp)
                totalXP += gain
            }
        }

        state.vector = vector
        state.peakComposite = max(state.peakComposite, peak)
        state.lastEvidenceAt = nodeEvidences.last?.timestamp
        let stage = MasteryStage.stage(for: min(59.9, vector.composite))
        let eligible = stage.level > MasteryStage.proficient.level ? MasteryStage.proficient : stage
        if eligible.level > state.highestStage.level {
            state.highestStageRawValue = eligible.rawValue
        }
    }
}
