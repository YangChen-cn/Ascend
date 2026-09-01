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

    func canContributeArtifactGrowth(_ evidence: EvidenceRecord) -> Bool {
        evidence.origin == .artifact || evidence.verificationLevel == .artifactCandidate
    }

    /// 将可回放的资料基础与直接测评/实作估计合并。资料不会覆盖已获得的表现投影。
    func projectedMasteryVector(nodeID: UUID, artifactVector: MasteryVector) -> MasteryVector {
        func projected(_ dimension: MasteryDimension, _ artifactValue: Double) -> Double {
            let key = MasteryEstimate.key(nodeID: nodeID, dimension: dimension)
            return max(artifactValue, (masteryEstimateByTrackKey[key]?.probability ?? 0) * 100)
        }
        return MasteryVector(
            exposure: projected(.exposure, artifactVector.exposure),
            understanding: projected(.understanding, artifactVector.understanding),
            practice: projected(.practice, artifactVector.practice),
            retention: projected(.retention, artifactVector.retention),
            autonomy: projected(.autonomy, artifactVector.autonomy)
        )
    }

    @discardableResult
    func applyArtifactEvidence(_ evidence: EvidenceRecord) -> Int {
        guard canContributeArtifactGrowth(evidence) else { return 0 }
        let nodeID = evidence.knowledgeNodeID

        // 1. 防重复刷分：同一个 evidence.id 只能记录一次 ledger
        if scoreLedgerEntries.contains(where: { $0.evidenceID == evidence.id && $0.knowledgeNodeID == nodeID }) {
            return 0
        }

        // 2. 防重复刷分：同一个 contentChangeHash 在同一知识点只能获得一次成长
        if let hash = evidence.contentChangeHash, !hash.isEmpty {
            let alreadyScored = evidenceRecords.contains { other in
                other.id != evidence.id &&
                other.knowledgeNodeID == nodeID &&
                other.contentChangeHash == hash &&
                scoreLedgerEntries.contains(where: { $0.evidenceID == other.id })
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

        // 未人工确认分类的 provisional artifact 赋予 65% 的置信度权重，避免误分类过度增长；已确认的使用 100%
        let effectiveConfidence = evidence.isVerified ? evidence.aiConfidence : (evidence.aiConfidence * 0.65)
        let coverage = ArtifactCoveragePolicy.normalized(evidence.artifactCoverage, for: evidence.kind)
        let foundation = ArtifactCoveragePolicy.applyingFoundation(
            for: evidence.kind,
            coverage: coverage,
            to: state.artifactVector
        )
        let input = ScoringInput(
            current: foundation,
            kind: evidence.kind,
            difficulty: evidence.difficulty,
            independence: evidence.independence,
            confidence: effectiveConfidence,
            stabilityDays: 0,
            lastEvidenceAt: state.lastEvidenceAt,
            timestamp: evidence.timestamp
        )
        let result = scoringEngine.apply(input)
        state.artifactVector = result.updated
        state.vector = projectedMasteryVector(nodeID: nodeID, artifactVector: result.updated)
        state.lastEvidenceAt = evidence.timestamp

        // Artifact 弱证据推动初窥 → 入门 → 通晓（最高自然成长至通晓门槛 59.9）
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
                reason: evidence.isVerified
                    ? "研习实据沉淀 · \(evidence.kind.title)"
                    : "研习实据初探 · \(evidence.kind.title)"
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
        // 全量重放仅用于人工确认分类后的基线校正：重建向量但不下调 peak、
        // 不重发 XP（历史结算以 ledger 为准），避免重放路径与增量路径口径漂移
        guard let state = masteryByNodeID[nodeID] else { return }
        let nodeEvidences = (evidenceByNodeID[nodeID] ?? [])
            .filter { canContributeArtifactGrowth($0) }
            .sorted { $0.timestamp < $1.timestamp }

        var vector = MasteryVector.zero
        let scoringEngine = ScoringEngine()

        var seenHashes = Set<String>()
        for ev in nodeEvidences {
            if let hash = ev.contentChangeHash, !hash.isEmpty {
                if seenHashes.contains(hash) { continue }
                seenHashes.insert(hash)
            }
            let effectiveConfidence = ev.isVerified ? ev.aiConfidence : (ev.aiConfidence * 0.65)
            let coverage = ArtifactCoveragePolicy.normalized(ev.artifactCoverage, for: ev.kind)
            let foundation = ArtifactCoveragePolicy.applyingFoundation(
                for: ev.kind,
                coverage: coverage,
                to: vector
            )
            let input = ScoringInput(
                current: foundation,
                kind: ev.kind,
                difficulty: ev.difficulty,
                independence: ev.independence,
                confidence: effectiveConfidence,
                stabilityDays: 0,
                lastEvidenceAt: ev.timestamp,
                timestamp: ev.timestamp
            )
            let res = scoringEngine.apply(input)
            vector = res.updated
        }

        state.artifactVector = vector
        state.vector = projectedMasteryVector(nodeID: nodeID, artifactVector: vector)
        state.lastEvidenceAt = [state.lastEvidenceAt, nodeEvidences.last?.timestamp]
            .compactMap { $0 }
            .max()
        let stage = MasteryStage.stage(for: min(59.9, vector.composite))
        let eligible = stage.level > MasteryStage.proficient.level ? MasteryStage.proficient : stage
        if eligible.level > state.highestStage.level {
            state.highestStageRawValue = eligible.rawValue
        }
    }

    /// 覆盖模型升级只重建由资料产生的基础；历史 XP、题目表现、复习和挑战均不触碰。
    @discardableResult
    func reconcileArtifactCoverageModelIfNeeded() throws -> Bool {
        let artifactEvidence = evidenceRecords.filter(canContributeArtifactGrowth)
        guard !artifactEvidence.isEmpty else {
            if automationDefaults.integer(forKey: AppConstants.artifactCoverageModelVersionKey) < ArtifactCoveragePolicy.modelVersion {
                automationDefaults.set(ArtifactCoveragePolicy.modelVersion, forKey: AppConstants.artifactCoverageModelVersionKey)
            }
            return false
        }

        let affectedNodeIDs = Set(artifactEvidence.map(\.knowledgeNodeID))
        // 不能只信 UserDefaults 的版本标记：应用若在 Core Data 迁移或写库中途退出，
        // 标记可能已写入，而新增的可选字段仍全是默认 0 / nil。以持久化资料的实际
        // 状态作为第二道幂等守卫，保证下一次启动会补齐，而不会把用户卡在旧低分上。
        let hasMissingCoverage = artifactEvidence.contains { $0.artifactCoverage == nil }
        let hasUnmaterializedFoundation = affectedNodeIDs.contains { nodeID in
            guard let state = masteryByNodeID[nodeID] else { return false }
            return state.artifactVector.composite == 0
        }
        let requiresReconciliation =
            automationDefaults.integer(forKey: AppConstants.artifactCoverageModelVersionKey) < ArtifactCoveragePolicy.modelVersion ||
            hasMissingCoverage ||
            hasUnmaterializedFoundation
        guard requiresReconciliation else { return false }

        for evidence in artifactEvidence where evidence.artifactCoverage == nil {
            evidence.artifactCoverage = ArtifactCoveragePolicy.legacyCoverage(for: evidence.kind)
        }

        for nodeID in affectedNodeIDs {
            guard let state = masteryByNodeID[nodeID] else { continue }
            replayArtifactEvidence(nodeID: nodeID)
            // 这是一轮模型校准而非新的学习行为：防止之后把既有资料基础重复结算成 XP。
            state.peakComposite = max(state.peakComposite, state.vector.composite)
        }

        try modelContext.save()
        automationDefaults.set(ArtifactCoveragePolicy.modelVersion, forKey: AppConstants.artifactCoverageModelVersionKey)
        return true
    }
}
