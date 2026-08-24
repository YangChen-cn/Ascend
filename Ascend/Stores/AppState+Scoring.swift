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
}
