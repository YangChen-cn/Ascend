import Foundation

extension AppState {
    func recordVerifiedPerformance(
        for nodeID: UUID,
        contextHash: String,
        summary: String,
        score: Double,
        scoringConfidence: Double,
        verificationLevel: VerificationLevel,
        assistanceMode: AssistanceMode,
        submittedEvidence: SubmittedPerformanceEvidence? = nil,
        occurredAt: Date = .now
    ) throws {
        guard let node = node(for: nodeID) else { throw AppStateError.missingKnowledgeNode }
        guard assistanceMode == .declaredUnassisted,
              verificationLevel == .productionRubric || verificationLevel == .productionDeterministic,
              (0...1).contains(score),
              !contextHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AssessmentFlowError.invalidPerformanceReceipt
        }
        guard verificationLevel == .productionDeterministic || scoringConfidence >= 0.8 else {
            throw AssessmentFlowError.lowPerformanceConfidence
        }
        guard !performanceReceipts.contains(where: {
            $0.knowledgeNodeID == nodeID && $0.contextHash == contextHash
        }) else {
            throw AssessmentFlowError.duplicatePerformanceContext
        }

        let receiptID = UUID()
        let receipt = PerformanceReceipt(
            id: receiptID,
            sessionID: receiptID,
            knowledgeNodeID: nodeID,
            contextHash: contextHash,
            verificationLevel: verificationLevel,
            assistanceMode: assistanceMode,
            score: score,
            scoringConfidence: verificationLevel == .productionDeterministic ? 1 : scoringConfidence,
            occurredAt: occurredAt,
            summary: summary
        )
        let activity = ActivityEvent(
            sourceID: receiptID,
            sourceKind: submittedEvidence?.sourceKind ?? .manual,
            timestamp: occurredAt,
            fingerprint: "performance-\(receiptID.uuidString)",
            contentChangeHash: submittedEvidence?.contentChangeHash,
            title: submittedEvidence?.title ?? "生产性实作 · \(node.name)",
            sourceLocator: submittedEvidence?.sourceLocator ?? "performance/\(receiptID.uuidString)",
            summary: summary,
            excerpt: "",
            isProcessed: true
        )
        let evidence = EvidenceRecord(
            activityID: activity.id,
            knowledgeNodeID: nodeID,
            kind: .project,
            timestamp: occurredAt,
            summary: summary,
            rationale: verificationLevel == .productionDeterministic ? "确定性实作验证" : "隐藏量规实作验证",
            difficulty: 1,
            independence: 1,
            aiConfidence: receipt.scoringConfidence,
            isVerified: true,
            fingerprint: "performance-evidence-\(receiptID.uuidString)",
            contentChangeHash: submittedEvidence?.contentChangeHash,
            origin: .productionPerformance,
            verificationLevel: verificationLevel,
            assistanceMode: assistanceMode
        )
        modelContext.insert(receipt)
        modelContext.insert(activity)
        modelContext.insert(evidence)
        performanceReceipts.append(receipt)
        performanceReceiptsByNodeID[nodeID, default: []].append(receipt)
        activityEvents.insert(activity, at: 0)
        evidenceRecords.insert(evidence, at: 0)
        evidenceByID[evidence.id] = evidence
        evidenceByNodeID[nodeID, default: []].insert(evidence, at: 0)

        let state = masteryByNodeID[nodeID] ?? makeMasteryState(nodeID: nodeID)
        let preSettlementComposite = state.vector.composite
        applyPerformanceObservation(receipt: receipt)
        synchronizePerformanceProjection(nodeID: nodeID)
        let newComposite = state.vector.composite
        let xpAwarded = Int((max(0, newComposite - state.peakComposite) * 10).rounded())
        state.peakComposite = max(state.peakComposite, newComposite)
        state.lifetimeXP += xpAwarded
        if let certified = readiness(for: nodeID, now: occurredAt)?.certifiedStage,
           certified.level > state.highestStage.level {
            state.highestStageRawValue = certified.rawValue
        }
        let ledger = ScoreLedgerEntry(
            evidenceID: evidence.id,
            knowledgeNodeID: nodeID,
            timestamp: occurredAt,
            previousComposite: preSettlementComposite,
            newComposite: newComposite,
            xpAwarded: xpAwarded,
            reason: "生产性实作表现"
        )
        modelContext.insert(ledger)
        scoreLedgerEntries.insert(ledger, at: 0)
        ledgerByNodeID[nodeID, default: []].append(ledger)
        try modelContext.save()
        refreshDerivedState()
        runTriggerEngine(now: occurredAt)
    }

    /// 用户明确提交后才会调用 AI 复核。声明只是上下文，绝不会直接形成已验证实据或完成挑战。
    func reviewAndSubmitChallengePerformanceEvidence(
        for challenge: Challenge,
        source: SubmittedPerformanceEvidence,
        nodeIDs: Set<UUID>,
        detail: String
    ) async throws -> ChallengeEvidenceReview {
        guard challenge.status == "in_progress",
              let automation = challengeAutomationStates.first(where: { $0.challengeID == challenge.id }),
              automation.acceptedAt != nil else {
            throw AssessmentFlowError.challengeNotActive
        }
        guard source.occurredAt >= Date.now.addingTimeInterval(-3 * 86_400) else {
            throw AssessmentFlowError.challengeEvidenceTooOld
        }
        let validNodeIDs = Set(challenge.knowledgeNodeIDs).intersection(nodeIDs)
        guard !validNodeIDs.isEmpty else { throw AssessmentFlowError.invalidPerformanceReceipt }

        guard let profile = activeEndpoint, profile.isEnabled else {
            throw AppStateError.missingEndpoint
        }
        guard !profile.selectedModelID.isEmpty else { throw AppStateError.missingModel }

        let detailText = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let targets = validNodeIDs.compactMap { nodeID in
            node(for: nodeID).map { ChallengeEvidenceReviewRequest.Target(id: nodeID, name: $0.name) }
        }
        let priorFailures = challengeEvidenceFailureReasons(for: challenge)
        let focusTexts = targets.map(\.name) + [challenge.title, challenge.challengeDescription] + priorFailures
        let refreshedExcerpt = try await ChallengeEvidenceExcerptLoader().load(
            source: source,
            focusTexts: focusTexts
        )
        let auditExcerpt = refreshedExcerpt ?? source.auditExcerpt
        guard !auditExcerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AssessmentFlowError.invalidPerformanceReceipt
        }
        let descriptor = AIEndpointDescriptor(
            id: profile.id,
            name: profile.name,
            baseURL: try EndpointURLBuilder().normalizedBaseURL(from: profile.baseURLString),
            selectedModelID: profile.selectedModelID,
            supportsStructuredOutputs: profile.supportsStructuredOutputs
        )
        let request = ChallengeEvidenceReviewRequest(
            challengeTitle: challenge.title,
            challengeDescription: challenge.challengeDescription,
            requirements: challengeRequirementDescriptions(for: challenge),
            targets: targets,
            source: .init(
                title: source.title,
                locator: source.sourceLocator,
                contentHash: source.contentChangeHash,
                occurredAt: source.occurredAt,
                auditExcerpt: String(auditExcerpt.prefix(AppConstants.maximumChallengeEvidenceExcerptLength))
            ),
            declarations: [
                "用户声明独立完成", "用户声明发生在真实项目/工作情境", "用户声明已解决核心问题", "用户声明结果达到质量要求"
            ],
            userDetail: String(detailText.prefix(1_000)),
            priorFailureReasons: priorFailures
        )
        let review = ChallengeEvidenceReviewPolicy.normalized(
            try await aiClient.reviewChallengeEvidence(
                endpoint: descriptor,
                modelID: profile.selectedModelID,
                apiKey: try await keychain.apiKey(endpointID: profile.id) ?? "",
                request: request
            )
        )
        try Task.checkCancellation()

        guard ChallengeEvidenceReviewPolicy.isPassing(review) else {
            try recordRejectedChallengeEvidenceReview(
                challenge: challenge,
                source: source,
                nodeIDs: validNodeIDs,
                review: review,
                occurredAt: .now
            )
            statusMessage = "实作证据未通过：\(review.failureReasons.first ?? "材料不足")"
            return review
        }

        let submittedAt = Date.now
        // 通过的复核在当前时刻形成直接实据；原始提交仍保留在定位和摘要中。
        let submittedSource = SubmittedPerformanceEvidence(
            title: source.title,
            sourceLocator: source.sourceLocator,
            contentChangeHash: "challenge-review:\(challenge.id.uuidString):\(source.contentChangeHash)",
            sourceKind: source.sourceKind,
            occurredAt: submittedAt
        )
        for nodeID in validNodeIDs {
            let nodeName = node(for: nodeID)?.name ?? "知识点"
            let summary = "AI 实作核验通过 · \(challenge.title) · \(source.title) · \(nodeName)：\(review.summary)（源哈希 \(source.contentChangeHash.prefix(12))）"
            try recordVerifiedPerformance(
                for: nodeID,
                contextHash: "challenge:\(challenge.id.uuidString):\(source.contentChangeHash)",
                summary: summary,
                score: review.confidence,
                scoringConfidence: review.confidence,
                verificationLevel: .productionRubric,
                assistanceMode: .declaredUnassisted,
                submittedEvidence: submittedSource,
                occurredAt: submittedAt
            )
        }
        statusMessage = "AI 已核验通过 \(validNodeIDs.count) 处知窍的挑战实作证据"
        return review
    }

    private func challengeEvidenceFailureReasons(for challenge: Challenge) -> [String] {
        evidenceRecords
            .filter {
                !$0.isVerified &&
                    $0.fingerprint.hasPrefix("challenge-review:\(challenge.id.uuidString):")
            }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)
            .map(\.rationale)
    }

    private func recordRejectedChallengeEvidenceReview(
        challenge: Challenge,
        source: SubmittedPerformanceEvidence,
        nodeIDs: Set<UUID>,
        review: ChallengeEvidenceReview,
        occurredAt: Date
    ) throws {
        let activityID = UUID()
        let activity = ActivityEvent(
            sourceID: activityID,
            sourceKind: source.sourceKind,
            timestamp: occurredAt,
            fingerprint: "challenge-review-activity:\(activityID.uuidString)",
            contentChangeHash: "challenge-review:\(challenge.id.uuidString):\(source.contentChangeHash)",
            title: "挑战候选实据 · \(source.title)",
            sourceLocator: source.sourceLocator,
            summary: review.summary,
            excerpt: "",
            isProcessed: true
        )
        modelContext.insert(activity)
        activityEvents.insert(activity, at: 0)
        for nodeID in nodeIDs {
            let evidence = EvidenceRecord(
                activityID: activity.id,
                knowledgeNodeID: nodeID,
                kind: .project,
                timestamp: occurredAt,
                summary: "挑战实作候选未通过 · \(challenge.title) · \(source.title)",
                rationale: review.failureReasons.joined(separator: "；"),
                difficulty: 1,
                independence: 1,
                aiConfidence: review.confidence,
                isVerified: false,
                fingerprint: "challenge-review:\(challenge.id.uuidString):\(source.contentChangeHash):\(nodeID.uuidString):\(activityID.uuidString)",
                contentChangeHash: activity.contentChangeHash,
                origin: .productionPerformance,
                verificationLevel: .artifactCandidate,
                assistanceMode: .declaredUnassisted
            )
            modelContext.insert(evidence)
            evidenceRecords.insert(evidence, at: 0)
            evidenceByID[evidence.id] = evidence
            evidenceByNodeID[nodeID, default: []].insert(evidence, at: 0)
        }
        try modelContext.save()
    }

    private func makeMasteryState(nodeID: UUID) -> MasteryState {
        let state = MasteryState(knowledgeNodeID: nodeID)
        modelContext.insert(state)
        masteryStates.append(state)
        masteryByNodeID[nodeID] = state
        return state
    }

    private func applyPerformanceObservation(receipt: PerformanceReceipt) {
        let trackKey = MasteryEstimate.key(nodeID: receipt.knowledgeNodeID, dimension: .autonomy)
        let estimate = masteryEstimateByTrackKey[trackKey] ?? {
            let estimate = MasteryEstimate(
                knowledgeNodeID: receipt.knowledgeNodeID,
                dimension: .autonomy,
                probability: MasteryEstimator.initialProbability,
                modelVersion: MasteryEstimator.modelVersion
            )
            modelContext.insert(estimate)
            masteryEstimates.append(estimate)
            masteryEstimateByTrackKey[trackKey] = estimate
            return estimate
        }()
        let grade = ProductionPerformanceGrade.grade(for: receipt.score)
        let passed = grade.isPassing
        let update = masteryEstimator.update(
            prior: estimate.probability,
            isCorrect: passed,
            guessProbability: grade.effectiveGuessProbability,
            slipProbability: grade.effectiveSlipProbability
        )
        let observation = MasteryObservation(
            canonicalKey: "receipt:\(receipt.id.uuidString)",
            sessionID: receipt.sessionID,
            itemID: receipt.id,
            responseID: receipt.id,
            knowledgeNodeID: receipt.knowledgeNodeID,
            dimension: .autonomy,
            isCorrect: passed,
            guessProbability: grade.effectiveGuessProbability,
            slipProbability: grade.effectiveSlipProbability,
            priorProbability: update.priorProbability,
            predictedCorrectProbability: update.predictedCorrectProbability,
            posteriorProbability: update.posteriorProbability,
            observedAt: receipt.occurredAt,
            modelVersion: MasteryEstimator.modelVersion
        )
        modelContext.insert(observation)
        masteryObservations.append(observation)
        observationsByNodeID[receipt.knowledgeNodeID, default: []].append(observation)
        estimate.probability = update.posteriorProbability
        estimate.observationCount += 1
        if passed { estimate.correctCount += 1 } else { estimate.incorrectCount += 1 }
        estimate.lastObservedAt = receipt.occurredAt
    }

    private func synchronizePerformanceProjection(nodeID: UUID) {
        guard let state = masteryByNodeID[nodeID] else { return }
        state.vector = projectedMasteryVector(nodeID: nodeID, artifactVector: state.artifactVector)
        state.lastEvidenceAt = observationsByNodeID[nodeID]?.filter { !$0.isInvalidated }.map(\.observedAt).max()
    }
}
