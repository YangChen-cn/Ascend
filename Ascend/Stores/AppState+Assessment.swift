import Foundation
import SwiftData

extension AppState {
    @discardableResult
    func persistEmbeddedAssessmentPackage(
        _ embedded: EmbeddedAssessmentPackage,
        activities: [ActivityEvent],
        generatorModelID: String
    ) throws -> AssessmentSession {
        let uniqueNames = embedded.knowledgeNames.reduce(into: [String]()) { result, name in
            guard !result.contains(where: { $0.localizedStandardCompare(name) == .orderedSame }) else { return }
            result.append(name)
        }
        let targetNodes = uniqueNames.prefix(5).compactMap { name in
            knowledgeNodes.first { $0.name.localizedStandardCompare(name) == .orderedSame }
        }
        guard !targetNodes.isEmpty,
              targetNodes.count == min(5, uniqueNames.count),
              targetNodes.allSatisfy({ $0.domain.localizedStandardCompare(embedded.domain) == .orderedSame }) else {
            throw AssessmentPackagePolicy.ValidationError.wrongNode
        }
        let targetNodeIDs = Set(targetNodes.map(\.id))
        let queuedSessions = activeAssessmentSessions.filter {
            !Set(self.items(for: $0.id).map(\.knowledgeNodeID)).isDisjoint(with: targetNodeIDs)
        }
        let queuedNodeIDs = Set(queuedSessions.flatMap { self.items(for: $0.id).map(\.knowledgeNodeID) })
        if targetNodeIDs.isSubset(of: queuedNodeIDs), let existing = queuedSessions.first {
            return existing
        }

        let targetByName = Dictionary(uniqueKeysWithValues: targetNodes.map {
            ($0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current), $0)
        })
        let request = AssessmentRequest(
            knowledgeNodeID: targetNodes[0].id,
            knowledgeName: "\(embedded.domain)领域综合验证",
            domain: embedded.domain,
            currentMasteryProbability: nil,
            kind: .baseline,
            sourceMaterials: activities.prefix(12).map {
                .init(
                    activityID: $0.id,
                    title: $0.title,
                    summary: $0.summary,
                    excerpt: String($0.excerpt.prefix(AppConstants.maximumAuditExcerptLength))
                )
            },
            targetKnowledgeNodes: targetNodes.map {
                .init(
                    knowledgeNodeID: $0.id,
                    knowledgeName: $0.name,
                    currentMasteryProbability: readiness(for: $0.id)?.currentComposite.mapToProbability,
                    preferredTier: preferredAssessmentTier(for: $0.id)
                )
            }
        )
        let convertedItems = embedded.items.compactMap { item -> AssessmentPackage.Item? in
            let key = item.knowledgeName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard let node = targetByName[key] else { return nil }
            return AssessmentPackage.Item(
                id: item.id,
                knowledgeNodeID: node.id,
                tier: item.tier,
                stem: item.stem,
                answerOptions: item.answerOptions,
                correctAnswerIndex: item.correctAnswerIndex,
                reasoningPrompt: item.reasoningPrompt,
                reasoningOptions: item.reasoningOptions,
                correctReasoningIndex: item.correctReasoningIndex,
                explanation: item.explanation,
                misconceptionTags: item.misconceptionTags,
                sourceActivityIDs: item.sourceActivityIDs
            )
        }
        let package = try AssessmentPackagePolicy.validated(
            AssessmentPackage(knowledgeNodeID: targetNodes[0].id, items: convertedItems),
            request: request
        )
        let session = AssessmentSession(
            knowledgeNodeID: targetNodes[0].id,
            kind: .baseline,
            generatorModelID: generatorModelID
        )
        let items = package.items.map { AssessmentItem(sessionID: session.id, item: $0) }
        modelContext.insert(session)
        items.forEach(modelContext.insert)
        assessmentSessions.insert(session, at: 0)
        assessmentItems.append(contentsOf: items)
        itemsBySessionID[session.id] = items
        if let first = assessmentAdaptiveEngine.nextItem(
            from: items,
            presentedItemIDs: [],
            responses: [],
            initialProbability: nil,
            preferredTierByNodeID: preferredTierMap(for: items)
        ) {
            session.presentedItemIDs = [first.id]
        }
        return session
    }

    func startAssessment(for nodeID: UUID) async throws -> AssessmentSession {
        if let existing = assessmentSessions.first(where: {
            $0.knowledgeNodeID == nodeID && ($0.statusRawValue == "active" || $0.statusRawValue == "awaitingReviewGrade")
        }) {
            return existing
        }
        guard let node = node(for: nodeID) else { throw AppStateError.missingKnowledgeNode }
        let duePlan = reviewPlans.first {
            $0.knowledgeNodeID == nodeID && $0.status == "due"
        }
        let activeChallenge = challenges.first {
            $0.status == "in_progress" && $0.knowledgeNodeIDs.contains(nodeID)
        }
        let kind: AssessmentKind = duePlan != nil ? .delayedReview : (activeChallenge != nil ? .challenge : .baseline)
        return try await startAssessment(
            targetNodes: [node],
            kind: kind,
            reviewPlanID: duePlan?.id
        )
    }

    func startDomainAssessment(for domainName: String) async throws -> AssessmentSession {
        if let existing = preparedDomainAssessment(for: domainName) {
            return existing
        }
        let candidates = domainAssessmentCandidates(for: domainName)
        guard !candidates.isEmpty else { throw AppStateError.missingKnowledgeNode }
        return try await startAssessment(targetNodes: candidates, kind: .baseline, reviewPlanID: nil)
    }

    func preparedDomainAssessment(for domainName: String) -> AssessmentSession? {
        assessmentSessions.first { session in
            guard session.statusRawValue == "active" else { return false }
            let sessionItems = items(for: session.id)
            return !sessionItems.isEmpty && sessionItems.allSatisfy { item in
                node(for: item.knowledgeNodeID)?.domain == domainName
            }
        }
    }

    var preparedVerificationDomainNames: [String] {
        pendingVerificationDomainNames.filter { preparedDomainAssessment(for: $0) != nil }
    }

    var pendingVerificationKnowledgeCount: Int {
        knowledgeNodes.count(where: needsChoiceAssessment)
    }

    var preparedVerificationKnowledgeCount: Int {
        let pendingIDs = Set(knowledgeNodes.filter(needsChoiceAssessment).map(\.id))
        return pendingIDs.intersection(queuedAssessmentNodeIDs).count
    }

    @discardableResult
    func prepareNextDomainAssessmentIfNeeded() async -> AssessmentSession? {
        if let ready = preparedVerificationDomainNames.first,
           let session = preparedDomainAssessment(for: ready) {
            return session
        }
        guard !isGeneratingAssessment else { return nil }
        guard let domainName = pendingVerificationDomainNames.first else { return nil }
        do {
            let session = try await startDomainAssessment(for: domainName)
            statusMessage = "“\(domainName)”领域验证题包已准备好"
            return session
        } catch {
            statusMessage = "领域验证题包准备失败：\(error.localizedDescription)"
            return nil
        }
    }

    func domainAssessmentCandidates(for domainName: String, limit: Int = 5) -> [KnowledgeNode] {
        nodes(inDomain: domainName)
            .filter(needsChoiceAssessment)
            .filter { !queuedAssessmentNodeIDs.contains($0.id) }
            .sorted { lhs, rhs in
                isHigherAssessmentPriority(lhs, than: rhs)
            }
            .prefix(max(1, limit))
            .map { $0 }
    }

    var pendingVerificationDomainNames: [String] {
        let preparedDomains = Set(activeAssessmentSessions.filter {
            $0.statusRawValue == "active"
        }.compactMap { session in
            items(for: session.id).first.flatMap { node(for: $0.knowledgeNodeID)?.domain }
        })
        let unqueuedDomains = Set(knowledgeNodes.filter {
            needsChoiceAssessment($0) && !queuedAssessmentNodeIDs.contains($0.id)
        }.map(\.domain))
        return preparedDomains.union(unqueuedDomains).sorted { lhs, rhs in
            if preparedDomains.contains(lhs) != preparedDomains.contains(rhs) {
                return preparedDomains.contains(lhs)
            }
            let lhsCandidate = domainAssessmentCandidates(for: lhs).first
            let rhsCandidate = domainAssessmentCandidates(for: rhs).first
            switch (lhsCandidate, rhsCandidate) {
            case let (lhsNode?, rhsNode?): return isHigherAssessmentPriority(lhsNode, than: rhsNode)
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
        }
    }

    private var activeAssessmentSessions: [AssessmentSession] {
        assessmentSessions.filter {
            $0.statusRawValue == "active" || $0.statusRawValue == "awaitingReviewGrade"
        }
    }

    private var queuedAssessmentNodeIDs: Set<UUID> {
        Set(activeAssessmentSessions.flatMap { items(for: $0.id).map(\.knowledgeNodeID) })
    }

    private func needsChoiceAssessment(_ node: KnowledgeNode) -> Bool {
        guard let snapshot = readiness(for: node.id) else { return true }
        return snapshot.certifiedStage.level < MasteryStage.integrated.level
    }

    private func isHigherAssessmentPriority(_ lhs: KnowledgeNode, than rhs: KnowledgeNode) -> Bool {
        let lhsCounts = primaryObservationCounts(for: lhs.id)
        let rhsCounts = primaryObservationCounts(for: rhs.id)
        let lhsFloor = lhsCounts.values.min() ?? 0
        let rhsFloor = rhsCounts.values.min() ?? 0
        if lhsFloor != rhsFloor { return lhsFloor < rhsFloor }
        let lhsTotal = lhsCounts.values.reduce(0, +)
        let rhsTotal = rhsCounts.values.reduce(0, +)
        if lhsTotal != rhsTotal { return lhsTotal < rhsTotal }
        let lhsDate = readiness(for: lhs.id)?.lastMeasuredAt ?? .distantPast
        let rhsDate = readiness(for: rhs.id)?.lastMeasuredAt ?? .distantPast
        if lhsDate != rhsDate { return lhsDate < rhsDate }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func primaryObservationCounts(for nodeID: UUID) -> [AssessmentTier: Int] {
        let valid = observationsByNodeID[nodeID, default: []].filter { !$0.isInvalidated }
        return Dictionary(uniqueKeysWithValues: AssessmentTier.allCases.map { tier in
            (tier, valid.count(where: { $0.dimension == tier.primaryDimension }))
        })
    }

    private func preferredAssessmentTier(for nodeID: UUID) -> AssessmentTier {
        let counts = primaryObservationCounts(for: nodeID)
        return AssessmentTier.allCases.min {
            let lhs = counts[$0, default: 0]
            let rhs = counts[$1, default: 0]
            return lhs == rhs ? $0.level < $1.level : lhs < rhs
        } ?? .foundational
    }

    private func preferredTierMap(for items: [AssessmentItem]) -> [UUID: AssessmentTier] {
        Dictionary(uniqueKeysWithValues: Set(items.map(\.knowledgeNodeID)).map {
            ($0, preferredAssessmentTier(for: $0))
        })
    }

    private func startAssessment(
        targetNodes: [KnowledgeNode],
        kind: AssessmentKind,
        reviewPlanID: UUID?
    ) async throws -> AssessmentSession {
        guard !isGeneratingAssessment else { throw AssessmentFlowError.inactiveSession }
        guard let anchorNode = targetNodes.first else { throw AppStateError.missingKnowledgeNode }
        let profile = activeEndpoint
            ?? endpointProfiles.first(where: { $0.isEnabled && !$0.selectedModelID.isEmpty })
            ?? endpointProfiles.first(where: \.isEnabled)
        guard let profile else { throw AppStateError.missingEndpoint }
        guard !profile.selectedModelID.isEmpty else { throw AppStateError.missingModel }

        isGeneratingAssessment = true
        defer { isGeneratingAssessment = false }

        let targetNodeIDs = Set(targetNodes.map(\.id))
        let linkedEvidence = evidenceRecords
            .filter { targetNodeIDs.contains($0.knowledgeNodeID) }
            .filter { $0.origin == .artifact }
            .sorted { $0.timestamp > $1.timestamp }
        let activityIDs = Set(linkedEvidence.prefix(12).map(\.activityID))
        let linkedActivities = try fetchActivities(ids: activityIDs)
        let sourceMaterials = linkedActivities.prefix(12).map {
            AssessmentRequest.SourceMaterial(
                activityID: $0.id,
                title: $0.title,
                summary: $0.summary,
                excerpt: String($0.excerpt.prefix(AppConstants.maximumAuditExcerptLength))
            )
        }
        let targetDescriptors = targetNodes.map {
            AssessmentRequest.TargetKnowledgeNode(
                knowledgeNodeID: $0.id,
                knowledgeName: $0.name,
                currentMasteryProbability: readiness(for: $0.id)?.currentComposite.mapToProbability,
                preferredTier: preferredAssessmentTier(for: $0.id)
            )
        }
        let measuredProbabilities = targetDescriptors.compactMap(\.currentMasteryProbability)
        let request = AssessmentRequest(
            knowledgeNodeID: anchorNode.id,
            knowledgeName: targetNodes.count == 1 ? anchorNode.name : "\(anchorNode.domain)领域综合验证",
            domain: anchorNode.domain,
            currentMasteryProbability: measuredProbabilities.isEmpty ? nil : measuredProbabilities.reduce(0, +) / Double(measuredProbabilities.count),
            kind: kind,
            sourceMaterials: Array(sourceMaterials),
            targetKnowledgeNodes: targetDescriptors
        )
        let descriptor = AIEndpointDescriptor(
            id: profile.id,
            name: profile.name,
            baseURL: try EndpointURLBuilder().normalizedBaseURL(from: profile.baseURLString),
            selectedModelID: profile.selectedModelID,
            supportsStructuredOutputs: profile.supportsStructuredOutputs
        )
        let generated = try await aiClient.generateAssessment(
            endpoint: descriptor,
            modelID: profile.selectedModelID,
            apiKey: try await keychain.apiKey(endpointID: profile.id) ?? "",
            request: request
        )
        let package = try AssessmentPackagePolicy.validated(generated, request: request)
        let session = AssessmentSession(
            knowledgeNodeID: anchorNode.id,
            kind: kind,
            generatorModelID: profile.selectedModelID,
            reviewPlanID: reviewPlanID
        )
        let items = package.items.map { AssessmentItem(sessionID: session.id, item: $0) }
        modelContext.insert(session)
        items.forEach(modelContext.insert)
        assessmentSessions.insert(session, at: 0)
        assessmentItems.append(contentsOf: items)
        itemsBySessionID[session.id] = items
        if let first = assessmentAdaptiveEngine.nextItem(
            from: items,
            presentedItemIDs: [],
            responses: [],
            initialProbability: request.currentMasteryProbability,
            preferredTierByNodeID: preferredTierMap(for: items)
        ) {
            session.presentedItemIDs = [first.id]
        }
        try modelContext.save()
        return session
    }

    func items(for sessionID: UUID) -> [AssessmentItem] {
        itemsBySessionID[sessionID] ?? []
    }

    func responses(for sessionID: UUID) -> [AssessmentResponse] {
        responsesBySessionID[sessionID] ?? []
    }

    func currentItem(for session: AssessmentSession) -> AssessmentItem? {
        let answeredIDs = Set(responses(for: session.id).map(\.itemID))
        return session.presentedItemIDs
            .first(where: { !answeredIDs.contains($0) })
            .flatMap { itemID in items(for: session.id).first(where: { $0.id == itemID }) }
    }

    func recordAssessmentResponse(
        session: AssessmentSession,
        item: AssessmentItem,
        selectedAnswerIndex: Int,
        selectedReasoningIndex: Int,
        usedAssistance: Bool
    ) throws -> AssessmentProgress {
        guard session.statusRawValue == "active" else { throw AssessmentFlowError.inactiveSession }
        guard item.sessionID == session.id else { throw AssessmentFlowError.missingItem }
        guard item.answerOptions.indices.contains(selectedAnswerIndex),
              item.reasoningOptions.indices.contains(selectedReasoningIndex) else {
            throw AssessmentFlowError.invalidSelection
        }
        guard !assessmentResponses.contains(where: { $0.itemID == item.id }) else {
            throw AssessmentFlowError.duplicateResponse
        }
        let response = AssessmentResponse(
            item: item,
            selectedAnswerIndex: selectedAnswerIndex,
            selectedReasoningIndex: selectedReasoningIndex,
            usedAssistance: usedAssistance
        )
        if usedAssistance {
            session.assistanceModeRawValue = AssistanceMode.aiAssisted.rawValue
        }
        modelContext.insert(response)
        assessmentResponses.append(response)
        responsesBySessionID[session.id, default: []].append(response)

        let sessionResponses = responses(for: session.id)
        let sessionItems = items(for: session.id)
        if let next = assessmentAdaptiveEngine.nextItem(
            from: sessionItems,
            presentedItemIDs: session.presentedItemIDs,
            responses: sessionResponses,
            initialProbability: readiness(for: session.knowledgeNodeID)?.currentComposite.mapToProbability,
            preferredTierByNodeID: preferredTierMap(for: sessionItems)
        ) {
            session.presentedItemIDs.append(next.id)
            try modelContext.save()
            return AssessmentProgress(nextItemID: next.id, isCompleted: false, requiresReviewGrade: false)
        }

        guard sessionResponses.count >= assessmentAdaptiveEngine.minimumResponseCount else {
            throw AssessmentFlowError.insufficientResponses
        }
        if session.kind == .delayedReview,
           sessionResponses.allSatisfy(\.isFullyCorrect),
           sessionResponses.allSatisfy({ !$0.usedAssistance }) {
            session.statusRawValue = "awaitingReviewGrade"
            try modelContext.save()
            return AssessmentProgress(nextItemID: nil, isCompleted: false, requiresReviewGrade: true)
        }
        try finalizeAssessment(session: session, reviewGrade: session.kind == .delayedReview ? .again : nil)
        return AssessmentProgress(nextItemID: nil, isCompleted: true, requiresReviewGrade: false)
    }

    func completeReviewAssessment(session: AssessmentSession, grade: MemoryReviewGrade) throws {
        guard session.kind == .delayedReview,
              session.statusRawValue == "awaitingReviewGrade",
              grade != .again else {
            throw AssessmentFlowError.reviewGradeNotExpected
        }
        try finalizeAssessment(session: session, reviewGrade: grade)
    }

    func invalidateAssessmentItem(_ item: AssessmentItem) throws {
        item.isInvalidated = true
        let affectedResponses = assessmentResponses.filter { $0.itemID == item.id }
        affectedResponses.forEach { $0.isInvalidated = true }
        let responseIDs = Set(affectedResponses.map(\.id))
        let affectedObservations = masteryObservations.filter { responseIDs.contains($0.responseID) }
        affectedObservations.forEach { $0.isInvalidated = true }
        for dimension in Set(affectedObservations.map(\.dimension)) {
            replayMasteryTrack(nodeID: item.knowledgeNodeID, dimension: dimension)
        }
        synchronizeMasteryProjection(nodeID: item.knowledgeNodeID)
        try modelContext.save()
        refreshDerivedState()
    }

    func brierScore() -> Double? {
        let valid = masteryObservations.filter { !$0.isInvalidated }
        let correctCount = valid.count(where: { $0.isCorrect })
        let incorrectCount = valid.count - correctCount
        guard valid.count >= 30, correctCount >= 5, incorrectCount >= 5 else { return nil }
        return valid.reduce(0.0) { result, observation in
            let outcome = observation.isCorrect ? 1.0 : 0.0
            return result + pow(observation.predictedCorrectProbability - outcome, 2)
        } / Double(valid.count)
    }

    private func finalizeAssessment(
        session: AssessmentSession,
        reviewGrade: MemoryReviewGrade?
    ) throws {
        let validResponses = responses(for: session.id).filter { !$0.isInvalidated }
        guard validResponses.count >= assessmentAdaptiveEngine.minimumResponseCount else {
            throw AssessmentFlowError.insufficientResponses
        }
        let responsePairs = validResponses.compactMap { response -> (AssessmentResponse, AssessmentItem)? in
            guard let item = assessmentItems.first(where: { $0.id == response.itemID }) else { return nil }
            return (response, item)
        }
        let groupedResponses = Dictionary(grouping: responsePairs, by: { $0.1.knowledgeNodeID })
        guard !groupedResponses.isEmpty else { throw AssessmentFlowError.missingItem }
        let measuredNodes = groupedResponses.keys.compactMap(node(for:))
        guard measuredNodes.count == groupedResponses.count else { throw AppStateError.missingKnowledgeNode }
        let now = Date.now
        let isDomainAssessment = measuredNodes.count > 1
        let domainName = measuredNodes.first?.domain ?? "学习领域"
        let activity = ActivityEvent(
            sourceID: session.id,
            sourceKind: .manual,
            timestamp: now,
            fingerprint: "assessment-\(session.id.uuidString)",
            title: isDomainAssessment ? "领域验证 · \(domainName)" : "主动验证 · \(measuredNodes[0].name)",
            sourceLocator: "assessment/\(session.id.uuidString)",
            summary: "完成 \(validResponses.count) 组双层情境题，覆盖 \(measuredNodes.count) 个知识点",
            excerpt: "",
            isProcessed: true
        )
        let evidenceKind: EvidenceKind = switch session.kind {
        case .delayedReview: .review
        case .challenge, .production: .project
        case .baseline: .exercise
        }
        modelContext.insert(activity)
        activityEvents.insert(activity, at: 0)

        var totalXPAwarded = 0
        var evidenceByMeasuredNodeID: [UUID: EvidenceRecord] = [:]
        for node in measuredNodes {
            guard let nodePairs = groupedResponses[node.id] else { continue }
            let nodeUsedAssistance = nodePairs.contains { $0.0.usedAssistance }
            let evidenceAssistance: AssistanceMode = nodeUsedAssistance ? .aiAssisted : .declaredUnassisted
            let evidence = EvidenceRecord(
                activityID: activity.id,
                knowledgeNodeID: node.id,
                kind: evidenceKind,
                timestamp: now,
                summary: "领域轮次验证：\(nodePairs.count) 组题",
                rationale: "由预置答案本地判分形成的直接表现",
                difficulty: 1,
                independence: nodeUsedAssistance ? 0 : 1,
                aiConfidence: 1,
                isVerified: true,
                fingerprint: "assessment-evidence-\(session.id.uuidString)-\(node.id.uuidString)",
                origin: .directAssessment,
                verificationLevel: .directChoice,
                assistanceMode: evidenceAssistance,
                assessmentSessionID: session.id
            )
            modelContext.insert(evidence)
            evidenceRecords.insert(evidence, at: 0)
            evidenceByID[evidence.id] = evidence
            evidenceByNodeID[node.id, default: []].insert(evidence, at: 0)
            evidenceByMeasuredNodeID[node.id] = evidence

            for (response, item) in nodePairs.sorted(by: { $0.0.answeredAt < $1.0.answeredAt }) where !response.usedAssistance {
                applyMasteryObservation(
                    session: session,
                    item: item,
                    response: response,
                    dimension: item.tier.primaryDimension,
                    isCorrect: response.answerIsCorrect
                )
                applyMasteryObservation(
                    session: session,
                    item: item,
                    response: response,
                    dimension: .understanding,
                    isCorrect: response.reasoningIsCorrect
                )
            }

            if session.kind == .delayedReview,
               let (lastResponse, lastItem) = nodePairs.max(by: { $0.0.answeredAt < $1.0.answeredAt }) {
                applyMasteryObservation(
                    session: session,
                    item: lastItem,
                    response: lastResponse,
                    dimension: .retention,
                    isCorrect: validResponses.allSatisfy(\.isFullyCorrect),
                    canonicalSuffix: "session-retention"
                )
            }

            let state = masteryByNodeID[node.id] ?? {
                let created = MasteryState(knowledgeNodeID: node.id)
                modelContext.insert(created)
                masteryStates.append(created)
                masteryByNodeID[node.id] = created
                return created
            }()
            let previousComposite = state.vector.composite
            synchronizeMasteryProjection(nodeID: node.id)
            let newComposite = state.vector.composite
            let xpAwarded = Int((max(0, newComposite - state.peakComposite) * 10).rounded())
            state.peakComposite = max(state.peakComposite, newComposite)
            state.lifetimeXP += xpAwarded
            state.confidence = min(100, Double(observationsByNodeID[node.id, default: []].count) / 6 * 100)
            let rawStage = MasteryStage.stage(for: newComposite)
            let eligibleStage = rawStage.level > MasteryStage.integrated.level ? MasteryStage.integrated : rawStage
            if eligibleStage.level > state.highestStage.level {
                state.highestStageRawValue = eligibleStage.rawValue
            }
            let ledger = ScoreLedgerEntry(
                evidenceID: evidence.id,
                knowledgeNodeID: node.id,
                timestamp: now,
                previousComposite: previousComposite,
                newComposite: newComposite,
                xpAwarded: xpAwarded,
                reason: isDomainAssessment ? "领域轮次主动测评" : "主动测评表现"
            )
            modelContext.insert(ledger)
            scoreLedgerEntries.insert(ledger, at: 0)
            ledgerByNodeID[node.id, default: []].append(ledger)
            totalXPAwarded += xpAwarded
        }

        if let reviewGrade,
           let evidence = evidenceByMeasuredNodeID[session.knowledgeNodeID],
           session.assistanceMode == .declaredUnassisted || reviewGrade == .again {
            registerAssessmentReview(
                session: session,
                evidence: evidence,
                grade: reviewGrade,
                at: now
            )
        }
        session.statusRawValue = "completed"
        session.completedAt = now
        try modelContext.save()
        refreshDerivedState()
        runTriggerEngine(now: now)
        let targetTitle = isDomainAssessment ? "\(domainName)领域" : "“\(measuredNodes[0].name)”"
        statusMessage = totalXPAwarded > 0
            ? "已完成\(targetTitle)主动验证，覆盖 \(measuredNodes.count) 个知识点，获得 \(totalXPAwarded) XP"
            : "已完成\(targetTitle)主动验证，\(measuredNodes.count) 个掌握估计已更新"
        Task { [weak self] in
            _ = await self?.prepareNextDomainAssessmentIfNeeded()
        }
    }

    private func applyMasteryObservation(
        session: AssessmentSession,
        item: AssessmentItem,
        response: AssessmentResponse,
        dimension: MasteryDimension,
        isCorrect: Bool,
        canonicalSuffix: String? = nil
    ) {
        let suffix = canonicalSuffix ?? dimension.rawValue
        let canonicalKey = "\(response.id.uuidString):\(suffix)"
        guard !masteryObservations.contains(where: { $0.canonicalKey == canonicalKey }) else { return }
        let trackKey = MasteryEstimate.key(nodeID: item.knowledgeNodeID, dimension: dimension)
        let estimate = masteryEstimateByTrackKey[trackKey] ?? {
            let created = MasteryEstimate(
                knowledgeNodeID: item.knowledgeNodeID,
                dimension: dimension,
                probability: MasteryEstimator.initialProbability,
                modelVersion: MasteryEstimator.modelVersion
            )
            modelContext.insert(created)
            masteryEstimates.append(created)
            masteryEstimateByTrackKey[trackKey] = created
            return created
        }()
        let update = masteryEstimator.update(prior: estimate.probability, isCorrect: isCorrect)
        let observation = MasteryObservation(
            canonicalKey: canonicalKey,
            sessionID: session.id,
            itemID: item.id,
            responseID: response.id,
            knowledgeNodeID: item.knowledgeNodeID,
            dimension: dimension,
            isCorrect: isCorrect,
            guessProbability: MasteryEstimator.fourChoiceGuessProbability,
            slipProbability: MasteryEstimator.defaultSlipProbability,
            priorProbability: update.priorProbability,
            predictedCorrectProbability: update.predictedCorrectProbability,
            posteriorProbability: update.posteriorProbability,
            observedAt: response.answeredAt,
            modelVersion: MasteryEstimator.modelVersion
        )
        modelContext.insert(observation)
        masteryObservations.append(observation)
        observationsByNodeID[item.knowledgeNodeID, default: []].append(observation)
        estimate.probability = update.posteriorProbability
        estimate.observationCount += 1
        if isCorrect { estimate.correctCount += 1 } else { estimate.incorrectCount += 1 }
        estimate.lastObservedAt = response.answeredAt
        estimate.modelVersion = MasteryEstimator.modelVersion
    }

    private func registerAssessmentReview(
        session: AssessmentSession,
        evidence: EvidenceRecord,
        grade: MemoryReviewGrade,
        at date: Date
    ) {
        let canonicalKey = "assessment:\(session.id.uuidString)"
        guard !memoryReviewEvents.contains(where: { $0.canonicalKey == canonicalKey }) else { return }
        let event = MemoryReviewEvent(
            knowledgeNodeID: session.knowledgeNodeID,
            evidenceID: evidence.id,
            canonicalKey: canonicalKey,
            grade: grade,
            reviewedAt: date,
            source: "directAssessment"
        )
        modelContext.insert(event)
        memoryReviewEvents.append(event)
        replayMemory(nodeID: session.knowledgeNodeID)
        if let reviewPlanID = session.reviewPlanID,
           let plan = reviewPlans.first(where: { $0.id == reviewPlanID }) {
            plan.status = "completed"
        }
        if let memory = memoryByNodeID[session.knowledgeNodeID],
           !reviewPlans.contains(where: {
               $0.knowledgeNodeID == session.knowledgeNodeID && ($0.status == "scheduled" || $0.status == "due")
           }) {
            let next = ReviewPlan(
                knowledgeNodeID: session.knowledgeNodeID,
                createdAt: date,
                scheduledAt: memory.nextReviewAt,
                reason: "FSRS 根据主动检索结果安排下一次温故",
                status: memory.nextReviewAt <= date ? "due" : "scheduled"
            )
            modelContext.insert(next)
            reviewPlans.append(next)
        }
    }

    private func replayMasteryTrack(nodeID: UUID, dimension: MasteryDimension) {
        let relevant = masteryObservations.filter {
            $0.knowledgeNodeID == nodeID && $0.dimension == dimension && !$0.isInvalidated
        }
        let trackKey = MasteryEstimate.key(nodeID: nodeID, dimension: dimension)
        guard let probability = masteryEstimator.replay(relevant.map {
            MasteryObservationSnapshot(
                canonicalKey: $0.canonicalKey,
                isCorrect: $0.isCorrect,
                guessProbability: $0.guessProbability,
                slipProbability: $0.slipProbability,
                observedAt: $0.observedAt,
                isInvalidated: $0.isInvalidated
            )
        }) else {
            if let estimate = masteryEstimateByTrackKey.removeValue(forKey: trackKey) {
                modelContext.delete(estimate)
                masteryEstimates.removeAll { $0.id == estimate.id }
            }
            return
        }
        let estimate = masteryEstimateByTrackKey[trackKey] ?? {
            let created = MasteryEstimate(
                knowledgeNodeID: nodeID,
                dimension: dimension,
                probability: probability,
                modelVersion: MasteryEstimator.modelVersion
            )
            modelContext.insert(created)
            masteryEstimates.append(created)
            masteryEstimateByTrackKey[trackKey] = created
            return created
        }()
        estimate.probability = probability
        estimate.observationCount = relevant.count
        estimate.correctCount = relevant.count(where: { $0.isCorrect })
        estimate.incorrectCount = relevant.count - estimate.correctCount
        estimate.lastObservedAt = relevant.map(\.observedAt).max()
        estimate.modelVersion = MasteryEstimator.modelVersion
    }

    private func synchronizeMasteryProjection(nodeID: UUID) {
        guard let state = masteryByNodeID[nodeID] else { return }
        func value(_ dimension: MasteryDimension) -> Double {
            let key = MasteryEstimate.key(nodeID: nodeID, dimension: dimension)
            return (masteryEstimateByTrackKey[key]?.probability ?? 0) * 100
        }
        state.vector = MasteryVector(
            exposure: value(.exposure),
            understanding: value(.understanding),
            practice: value(.practice),
            retention: value(.retention),
            autonomy: value(.autonomy)
        )
        state.lastEvidenceAt = observationsByNodeID[nodeID]?.filter({ !$0.isInvalidated }).map(\.observedAt).max()
    }
}

private extension Double {
    var mapToProbability: Double { (self / 100).clamped(to: 0...1) }
}
