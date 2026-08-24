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
        if let existing = activeAssessmentSession(covering: targetNodeIDs) {
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
            sourceMaterials: activities.prefix(AppConstants.maximumAssessmentSourceMaterialsPerPackage).map {
                .init(
                    activityID: $0.id,
                    title: $0.title,
                    summary: $0.summary,
                    excerpt: String($0.excerpt.prefix(AppConstants.maximumLLMExcerptLength))
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

    func activeAssessmentSession(covering targetIDs: Set<UUID>) -> AssessmentSession? {
        guard !targetIDs.isEmpty else { return nil }
        return activeAssessmentSessions.first { session in
            let sessionNodeIDs = Set(items(for: session.id).map(\.knowledgeNodeID))
            var allSessionNodes = sessionNodeIDs
            allSessionNodes.insert(session.knowledgeNodeID)
            return targetIDs.isSubset(of: allSessionNodes)
        }
    }

    func activeAssessmentSession(covering nodeID: UUID) -> AssessmentSession? {
        activeAssessmentSessions.first { session in
            session.knowledgeNodeID == nodeID || items(for: session.id).contains { $0.knowledgeNodeID == nodeID }
        }
    }

    func cachedAssessment(for nodeID: UUID) -> AssessmentSession? {
        activeAssessmentSession(covering: nodeID)
    }

    func hasCachedAssessment(for nodeID: UUID) -> Bool {
        cachedAssessment(for: nodeID) != nil
    }

    func cachedDomainAssessment(for domainName: String) -> AssessmentSession? {
        let domainNodeIDs = Set(nodes(inDomain: domainName).map(\.id))
        return activeAssessmentSessions.first { session in
            session.kind != .delayedReview &&
            items(for: session.id).contains { domainNodeIDs.contains($0.knowledgeNodeID) }
        }
    }

    func startAssessment(for nodeID: UUID) async throws -> AssessmentSession {
        if let existing = cachedAssessment(for: nodeID) {
            assessmentPreparationMessage = "“\(node(for: nodeID)?.name ?? "该知识点")”研习题包已经准备好（0 AI）"
            return existing
        }
        guard let node = node(for: nodeID) else { throw AppStateError.missingKnowledgeNode }
        let activeChallenge = challenges.first {
            $0.status == "in_progress" && $0.knowledgeNodeIDs.contains(nodeID)
        }
        let kind: AssessmentKind = activeChallenge != nil ? .challenge : .baseline
        let stage = readiness(for: nodeID)?.certifiedStage ?? .entry
        let actionWord = stage.level >= MasteryStage.proficient.level ? "印证" : "研习"
        assessmentPreparationMessage = "正在为“\(node.name)”生成\(actionWord)题包（1 次 AI 请求）…"
        do {
            let session = try await startAssessment(
                targetNodes: [node],
                kind: kind,
                reviewPlanID: nil
            )
            assessmentPreparationMessage = "“\(node.name)”\(actionWord)题包已准备好；开始答题不再调用 AI"
            return session
        } catch {
            assessmentPreparationMessage = "备题失败：\(error.localizedDescription)"
            throw error
        }
    }

    func startDomainAssessment(for domainName: String) async throws -> AssessmentSession {
        if let existing = cachedDomainAssessment(for: domainName) {
            assessmentPreparationMessage = "“\(domainName)”领域研习题包已经准备好（0 AI）"
            return existing
        }
        let candidates = domainAssessmentCandidates(for: domainName)
        if candidates.isEmpty, let existing = preparedDomainAssessment(for: domainName) {
            assessmentPreparationMessage = "“\(domainName)”领域研习题包已经准备好（0 AI）"
            return existing
        }
        let targetNodes = !candidates.isEmpty ? candidates : Array(nodes(inDomain: domainName).prefix(5))
        guard !targetNodes.isEmpty else { throw AppStateError.missingKnowledgeNode }
        assessmentPreparationMessage = "正在为“\(domainName)”生成 1 个研习题包（覆盖 \(targetNodes.count) 个知识点）…"
        do {
            let session = try await startAssessment(targetNodes: targetNodes, kind: .baseline, reviewPlanID: nil)
            assessmentPreparationMessage = "“\(domainName)”研习题包已备好：覆盖 \(targetNodes.count) 个知识点"
            return session
        } catch {
            assessmentPreparationMessage = "备题失败：\(error.localizedDescription)"
            throw error
        }
    }

    func preparedDomainAssessment(for domainName: String) -> AssessmentSession? {
        let candidates = domainAssessmentCandidates(for: domainName)
        if !candidates.isEmpty, let covering = activeAssessmentSession(covering: Set(candidates.map(\.id))) {
            return covering
        }
        return activeAssessmentSessions.first { session in
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
        let preparedIDs = preparedChoiceAssessmentNodeIDs
        let dueIDs = Set(knowledgeNodes.filter { isChoiceAssessmentDue($0) }.map(\.id))
        return preparedIDs.union(dueIDs).count
    }

    var preparedVerificationKnowledgeCount: Int {
        preparedChoiceAssessmentNodeIDs.count
    }

    @discardableResult
    func prepareNextDomainAssessmentIfNeeded() async -> AssessmentSession? {
        guard !isGeneratingAssessment else { return nil }
        if let ready = preparedVerificationDomainNames.first,
           let existing = preparedDomainAssessment(for: ready) {
            return existing
        }
        let unqueuedCount = pendingVerificationKnowledgeCount - preparedVerificationKnowledgeCount
        if unqueuedCount > 0 {
            return await prepareAllPendingAssessments()
        }
        return nil
    }

    @discardableResult
    func prepareAllPendingAssessments() async -> AssessmentSession? {
        guard !isGeneratingAssessment else { return nil }
        let groups = pendingAssessmentTargetGroups()
        if groups.isEmpty {
            guard let domain = preparedVerificationDomainNames.first else { return nil }
            return preparedDomainAssessment(for: domain)
        }
        let totalTargets = groups.reduce(0) { $0 + $1.count }
        let maximumPackagesPerRequest = max(
            1,
            AppConstants.maximumAssessmentTargetsPerRequest / AppConstants.maximumAssessmentTargetsPerPackage
        )
        assessmentPreparationMessage = "正在批量备题：已准备 0/\(totalTargets) 个知识点；当前每次最多 \(AppConstants.maximumAssessmentTargetsPerRequest) 个…"

        let profile = activeEndpoint
            ?? endpointProfiles.first(where: { $0.isEnabled && !$0.selectedModelID.isEmpty })
            ?? endpointProfiles.first(where: \.isEnabled)
        guard let profile else {
            assessmentPreparationMessage = "备题失败：未配置可用的 AI 接口"
            return nil
        }
        guard !profile.selectedModelID.isEmpty else {
            assessmentPreparationMessage = "备题失败：未选择 AI 模型"
            return nil
        }

        isGeneratingAssessment = true
        defer { isGeneratingAssessment = false }
        var preparedTargets = 0
        var firstSession: AssessmentSession?
        var packageLimit = preferredAssessmentPackageLimit(
            endpointID: profile.id,
            modelID: profile.selectedModelID,
            maximum: maximumPackagesPerRequest
        )
        var usesSinglePackageSchema = false
        var didAdaptBatchLimit = packageLimit < maximumPackagesPerRequest
        var minimumTransportRetryCount = 0
        var fallbackHistory: [String] = []
        do {
            let descriptor = AIEndpointDescriptor(
                id: profile.id,
                name: profile.name,
                baseURL: try EndpointURLBuilder().normalizedBaseURL(from: profile.baseURLString),
                selectedModelID: profile.selectedModelID,
                supportsStructuredOutputs: profile.supportsStructuredOutputs
            )
            let apiKey = try await keychain.apiKey(endpointID: profile.id) ?? ""
            var remainingGroups = groups
            while !remainingGroups.isEmpty {
                let groupBatch = nextAssessmentGroupBatch(
                    from: remainingGroups,
                    packageLimit: packageLimit
                )
                let requests = try groupBatch.map { try makeAssessmentRequest(targetNodes: $0, kind: .baseline) }
                let currentTargetLimit = packageLimit * AppConstants.maximumAssessmentTargetsPerPackage
                let requestedTargetCount = requests.reduce(0) { $0 + $1.targetKnowledgeNodes.count }
                assessmentPreparationMessage = "正在批量备题：已准备 \(preparedTargets)/\(totalTargets) 个知识点；当前每次最多 \(currentTargetLimit) 个…"
                do {
                    if usesSinglePackageSchema {
                        guard let request = requests.first, requests.count == 1 else {
                            throw AssessmentGenerationError.batchFormatIncompatible("单题包兼容请求包含多个题包")
                        }
                        let session = try await generateAndPersistSingleAssessment(
                            endpoint: descriptor,
                            modelID: profile.selectedModelID,
                            apiKey: apiKey,
                            request: request
                        )
                        firstSession = firstSession ?? session
                    } else {
                        let generated = try await aiClient.generateAssessmentBatch(
                            endpoint: descriptor,
                            modelID: profile.selectedModelID,
                            apiKey: apiKey,
                            requests: requests
                        )
                        guard generated.count == requests.count else {
                            throw AssessmentGenerationError.batchFormatIncompatible("批量题包数量与请求不一致")
                        }
                        let validatedPackages = try requests.enumerated().map { offset, request in
                            try AssessmentPackagePolicy.validated(generated[offset], request: request)
                        }
                        var persistedSessions: [AssessmentSession] = []
                        for (offset, request) in requests.enumerated() {
                            let session = try persistAssessmentPackage(
                                validatedPackages[offset],
                                request: request,
                                kind: .baseline,
                                generatorModelID: profile.selectedModelID,
                                reviewPlanID: nil
                            )
                            persistedSessions.append(session)
                        }
                        try modelContext.save()
                        firstSession = firstSession ?? persistedSessions.first
                    }
                    preparedTargets += requestedTargetCount
                    remainingGroups.removeFirst(groupBatch.count)
                    minimumTransportRetryCount = 0
                    if !usesSinglePackageSchema,
                       requestedTargetCount == currentTargetLimit,
                       packageLimit < maximumPackagesPerRequest {
                        packageLimit += 1
                        didAdaptBatchLimit = true
                        rememberAssessmentPackageLimit(
                            packageLimit,
                            endpointID: profile.id,
                            modelID: profile.selectedModelID
                        )
                        assessmentPreparationMessage = "本批成功，已把动态上限提升为每次最多 \(packageLimit * AppConstants.maximumAssessmentTargetsPerPackage) 个知识点；已准备 \(preparedTargets)/\(totalTargets) 个…"
                    }
                } catch let generationError as AssessmentGenerationError {
                    guard let details = generationError.adaptiveFallbackDetails else {
                        throw generationError
                    }
                    let fallbackReason = switch generationError {
                    case .transportInterrupted: "批量连接中断"
                    case .batchFormatIncompatible: "批量格式不兼容"
                    case .unsupported: "批量请求不受支持"
                    }
                    fallbackHistory.append("\(fallbackReason)：\(details)")
                    if case .unsupported = generationError {
                        packageLimit = 1
                        usesSinglePackageSchema = true
                    } else if groupBatch.count > 1 {
                        packageLimit = max(1, min(packageLimit - 1, groupBatch.count - 1))
                    } else if case .batchFormatIncompatible = generationError, !usesSinglePackageSchema {
                        packageLimit = 1
                        usesSinglePackageSchema = true
                    } else if case .transportInterrupted = generationError,
                              groupBatch.count == 1,
                              minimumTransportRetryCount < 1 {
                        minimumTransportRetryCount += 1
                        didAdaptBatchLimit = true
                        assessmentPreparationMessage = "最小批次连接中断（\(details)），正在使用新的网络会话重试一次；已准备 \(preparedTargets)/\(totalTargets) 个…"
                        continue
                    } else {
                        throw generationError
                    }
                    didAdaptBatchLimit = true
                    rememberAssessmentPackageLimit(
                        packageLimit,
                        endpointID: profile.id,
                        modelID: profile.selectedModelID
                    )
                    let reducedTargetLimit = packageLimit * AppConstants.maximumAssessmentTargetsPerPackage
                    assessmentPreparationMessage = "\(fallbackReason)（\(details)），已自动缩小为每次最多 \(reducedTargetLimit) 个知识点并重试；已准备 \(preparedTargets)/\(totalTargets) 个…"
                }
            }
            let compatibilityNote: String
            if usesSinglePackageSchema {
                compatibilityNote = "；接口已使用单题包结构兼容模式"
            } else if didAdaptBatchLimit {
                compatibilityNote = "；动态批次上限为 \(packageLimit * AppConstants.maximumAssessmentTargetsPerPackage) 个知识点"
            } else {
                compatibilityNote = ""
            }
            assessmentPreparationMessage = "批量备题完成：已为 \(preparedTargets) 个知识点准备 \(groups.count) 个题包\(compatibilityNote)；答题时不再调用 AI"
            statusMessage = "已完成 \(preparedTargets) 个知识点的批量备题"
            await sendAssessmentReadyNotificationIfNeeded()
            return firstSession
        } catch {
            modelContext.rollback()
            reload()
            let failurePrefix = didAdaptBatchLimit ? "动态备题中断" : "批量备题中断"
            let priorFailures = fallbackHistory.isEmpty
                ? ""
                : "；此前失败：\(fallbackHistory.suffix(2).joined(separator: "；"))"
            assessmentPreparationMessage = "\(failurePrefix)：已准备 \(preparedTargets)/\(totalTargets) 个知识点\(priorFailures)；最终错误：\(error.localizedDescription)"
            statusMessage = "批量备题失败：\(error.localizedDescription)"
            return nil
        }
    }

    private func estimateSourceMaterialsLength(for nodes: [KnowledgeNode]) -> Int {
        let nodeIDs = Set(nodes.map(\.id))
        let linked = evidenceRecords.filter { nodeIDs.contains($0.knowledgeNodeID) && $0.origin == .artifact }
        let activityIDs = Set(linked.prefix(AppConstants.maximumAssessmentSourceMaterialsPerPackage).map(\.activityID))
        let activities = (try? fetchActivities(ids: activityIDs)) ?? []
        return activities.reduce(0) { $0 + min($1.excerpt.count, AppConstants.maximumLLMExcerptLength) + $1.summary.count }
    }

    private func nextAssessmentGroupBatch(
        from groups: [[KnowledgeNode]],
        packageLimit: Int
    ) -> [[KnowledgeNode]] {
        let boundedPackageLimit = min(max(1, packageLimit), groups.count)
        var count = AssessmentBatchPlanner.balancedPackageCounts(
            totalPackages: groups.count,
            maximumPackagesPerRequest: boundedPackageLimit
        ).first ?? 1
        while count > 1 {
            let candidate = Array(groups.prefix(count))
            let estimatedCharacters = candidate.reduce(0) { total, group in
                total + estimateSourceMaterialsLength(for: group)
            }
            if estimatedCharacters <= AppConstants.maximumBatchContextCharacters {
                return candidate
            }
            count -= 1
        }
        return Array(groups.prefix(1))
    }

    private struct AssessmentPriorityKey: Comparable {
        let minObservationTierCount: Int
        let totalObservationCount: Int
        let lastMeasuredAt: Date
        let name: String

        static func < (lhs: AssessmentPriorityKey, rhs: AssessmentPriorityKey) -> Bool {
            if lhs.minObservationTierCount != rhs.minObservationTierCount {
                return lhs.minObservationTierCount < rhs.minObservationTierCount
            }
            if lhs.totalObservationCount != rhs.totalObservationCount {
                return lhs.totalObservationCount < rhs.totalObservationCount
            }
            if lhs.lastMeasuredAt != rhs.lastMeasuredAt {
                return lhs.lastMeasuredAt < rhs.lastMeasuredAt
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func assessmentPriorityKey(for node: KnowledgeNode) -> AssessmentPriorityKey {
        let counts = primaryObservationCounts(for: node.id)
        let floor = counts.values.min() ?? 0
        let total = counts.values.reduce(0, +)
        let lastMeasured = readiness(for: node.id)?.lastMeasuredAt ?? .distantPast
        return AssessmentPriorityKey(
            minObservationTierCount: floor,
            totalObservationCount: total,
            lastMeasuredAt: lastMeasured,
            name: node.name
        )
    }

    func domainAssessmentCandidates(for domainName: String, limit: Int = 5) -> [KnowledgeNode] {
        let unqueuedNodes = nodes(inDomain: domainName)
            .filter { isChoiceAssessmentDue($0) }
            .filter { !queuedAssessmentNodeIDs.contains($0.id) }
        guard !unqueuedNodes.isEmpty else { return [] }
        let keys = Dictionary(uniqueKeysWithValues: unqueuedNodes.map { ($0.id, assessmentPriorityKey(for: $0)) })
        return unqueuedNodes
            .sorted { lhs, rhs in
                guard let lKey = keys[lhs.id], let rKey = keys[rhs.id] else { return false }
                return lKey < rKey
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
            isChoiceAssessmentDue($0) && !queuedAssessmentNodeIDs.contains($0.id)
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

    private var preparedChoiceAssessmentNodeIDs: Set<UUID> {
        Set(activeAssessmentSessions
            .filter { $0.kind != .delayedReview }
            .flatMap { items(for: $0.id).map(\.knowledgeNodeID) }
            .filter { nodeID in
                guard let node = node(for: nodeID) else { return false }
                return needsChoiceAssessment(node)
            })
    }

    private func needsChoiceAssessment(_ node: KnowledgeNode) -> Bool {
        guard let snapshot = readiness(for: node.id) else { return false }
        guard snapshot.certifiedStage.level < MasteryStage.integrated.level else { return false }
        // 突破验证候选：初窥、入门阶段只管平时自然成长；通晓阶段且成长接近融会门槛（>=45）才进入印证候选
        return snapshot.currentComposite >= 45.0
    }

    private func isChoiceAssessmentDue(_ node: KnowledgeNode, now: Date = .now) -> Bool {
        guard needsChoiceAssessment(node) else { return false }
        let lastMeasuredAt = readiness(for: node.id, now: now)?.lastMeasuredAt
        let choiceSessionIDs = Set(assessmentSessions.lazy
            .filter { $0.kind != .delayedReview }
            .map(\.id))
        let lastAttemptedAt = assessmentResponses
            .filter { $0.knowledgeNodeID == node.id && choiceSessionIDs.contains($0.sessionID) }
            .map(\.answeredAt)
            .max()
        guard let latestPerformanceAt = [lastMeasuredAt, lastAttemptedAt].compactMap({ $0 }).max() else {
            return true
        }
        return now.timeIntervalSince(latestPerformanceAt) >= AppConstants.choiceAssessmentRemeasurementInterval
    }

    @discardableResult
    func retireRedundantPreparedAssessments(now: Date = .now) -> Int {
        let redundant = activeAssessmentSessions.filter { session in
            guard session.kind == .baseline,
                  responses(for: session.id).isEmpty else { return false }
            let nodeIDs = Set(items(for: session.id).map(\.knowledgeNodeID))
            guard !nodeIDs.isEmpty else { return false }
            return nodeIDs.allSatisfy { nodeID in
                guard let node = node(for: nodeID) else { return true }
                guard let snapshot = readiness(for: nodeID, now: now) else { return false }
                // 1. 已认证融会及以上 -> 废弃
                if snapshot.certifiedStage.level >= MasteryStage.integrated.level {
                    return true
                }
                // 2. 刚刚已测过（在重测冷却期内） -> 废弃多余题包
                if let lastMeasuredAt = snapshot.lastMeasuredAt,
                   now.timeIntervalSince(lastMeasuredAt) < AppConstants.choiceAssessmentRemeasurementInterval {
                    return true
                }
                return false
            }
        }
        redundant.forEach {
            $0.statusRawValue = "superseded"
            $0.completedAt = now
        }
        return redundant.count
    }

    private func isHigherAssessmentPriority(_ lhs: KnowledgeNode, than rhs: KnowledgeNode) -> Bool {
        assessmentPriorityKey(for: lhs) < assessmentPriorityKey(for: rhs)
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

    private func pendingAssessmentTargetGroups() -> [[KnowledgeNode]] {
        let orderedDomains = Set(knowledgeNodes.map(\.domain)).sorted()
        return orderedDomains.flatMap { domain in
            domainAssessmentCandidates(for: domain, limit: .max)
                .chunked(into: AppConstants.maximumAssessmentTargetsPerPackage)
        }
    }

    private func makeAssessmentRequest(
        targetNodes: [KnowledgeNode],
        kind: AssessmentKind
    ) throws -> AssessmentRequest {
        guard let anchorNode = targetNodes.first else { throw AppStateError.missingKnowledgeNode }
        let targetNodeIDs = Set(targetNodes.map(\.id))
        let linkedEvidence = evidenceRecords
            .filter { targetNodeIDs.contains($0.knowledgeNodeID) }
            .filter { $0.origin == .artifact }
            .sorted { $0.timestamp > $1.timestamp }
        let activityIDs = Set(
            linkedEvidence
                .prefix(AppConstants.maximumAssessmentSourceMaterialsPerPackage)
                .map(\.activityID)
        )
        let linkedActivities = try fetchActivities(ids: activityIDs)
        let sourceMaterials = linkedActivities
            .prefix(AppConstants.maximumAssessmentSourceMaterialsPerPackage)
            .map {
                AssessmentRequest.SourceMaterial(
                    activityID: $0.id,
                    title: String($0.title.prefix(AppConstants.maximumAssessmentSourceTitleLength)),
                    summary: String($0.summary.prefix(AppConstants.maximumAssessmentSourceSummaryLength)),
                    excerpt: String($0.excerpt.prefix(AppConstants.maximumLLMExcerptLength))
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
        return AssessmentRequest(
            knowledgeNodeID: anchorNode.id,
            knowledgeName: targetNodes.count == 1 ? anchorNode.name : "\(anchorNode.domain)领域综合验证",
            domain: anchorNode.domain,
            currentMasteryProbability: measuredProbabilities.isEmpty ? nil : measuredProbabilities.reduce(0, +) / Double(measuredProbabilities.count),
            kind: kind,
            sourceMaterials: Array(sourceMaterials),
            targetKnowledgeNodes: targetDescriptors
        )
    }

    private func startAssessment(
        targetNodes: [KnowledgeNode],
        kind: AssessmentKind,
        reviewPlanID: UUID?
    ) async throws -> AssessmentSession {
        guard !isGeneratingAssessment else { throw AssessmentFlowError.inactiveSession }
        let targetIDs = Set(targetNodes.map(\.id))
        if let existing = activeAssessmentSessions.first(where: { session in
            guard session.kind == kind,
                  session.reviewPlanID == reviewPlanID else { return false }
            let sessionNodeIDs = Set(items(for: session.id).map(\.knowledgeNodeID))
            return targetIDs.isSubset(of: sessionNodeIDs)
        }) {
            return existing
        }
        let profile = activeEndpoint
            ?? endpointProfiles.first(where: { $0.isEnabled && !$0.selectedModelID.isEmpty })
            ?? endpointProfiles.first(where: \.isEnabled)
        guard let profile else { throw AppStateError.missingEndpoint }
        guard !profile.selectedModelID.isEmpty else { throw AppStateError.missingModel }

        isGeneratingAssessment = true
        defer { isGeneratingAssessment = false }

        let request = try makeAssessmentRequest(targetNodes: targetNodes, kind: kind)
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
        let session = try persistAssessmentPackage(
            package,
            request: request,
            kind: kind,
            generatorModelID: profile.selectedModelID,
            reviewPlanID: reviewPlanID
        )
        try modelContext.save()
        return session
    }

    private func generateAndPersistSingleAssessment(
        endpoint: AIEndpointDescriptor,
        modelID: String,
        apiKey: String,
        request: AssessmentRequest
    ) async throws -> AssessmentSession {
        let generated = try await aiClient.generateAssessment(
            endpoint: endpoint,
            modelID: modelID,
            apiKey: apiKey,
            request: request
        )
        let package = try AssessmentPackagePolicy.validated(generated, request: request)
        let session = try persistAssessmentPackage(
            package,
            request: request,
            kind: .baseline,
            generatorModelID: modelID,
            reviewPlanID: nil
        )
        try modelContext.save()
        return session
    }

    private func preferredAssessmentPackageLimit(
        endpointID: UUID,
        modelID: String,
        maximum: Int
    ) -> Int {
        let key = assessmentCompatibilityKey(endpointID: endpointID, modelID: modelID)
        var records = assessmentBatchLimitRecords()
        guard let record = records[key] else { return maximum }
        let isCurrent = Date().timeIntervalSince1970 - record.recordedAt
            < AppConstants.assessmentBatchLimitCompatibilityTTL
        guard isCurrent else {
            records.removeValue(forKey: key)
            saveAssessmentBatchLimitRecords(records)
            return maximum
        }
        return min(maximum, max(1, record.packageLimit))
    }

    private func rememberAssessmentPackageLimit(_ packageLimit: Int, endpointID: UUID, modelID: String) {
        var records = assessmentBatchLimitRecords()
        records[assessmentCompatibilityKey(endpointID: endpointID, modelID: modelID)] = (
            packageLimit: max(1, packageLimit),
            recordedAt: Date().timeIntervalSince1970
        )
        saveAssessmentBatchLimitRecords(records)
    }

    private func assessmentBatchLimitRecords() -> [String: (packageLimit: Int, recordedAt: Double)] {
        (automationDefaults.dictionary(forKey: AppConstants.assessmentBatchLimitCompatibilityKey) ?? [:])
            .reduce(into: [:]) { result, entry in
                guard let encoded = entry.value as? String else { return }
                let components = encoded.split(separator: "|", maxSplits: 1)
                if components.count == 2,
                   let packageLimit = Int(components[0]),
                   let recordedAt = Double(components[1]) {
                    result[entry.key] = (packageLimit, recordedAt)
                }
            }
    }

    private func saveAssessmentBatchLimitRecords(
        _ records: [String: (packageLimit: Int, recordedAt: Double)]
    ) {
        let encoded = records.mapValues { "\($0.packageLimit)|\($0.recordedAt)" }
        automationDefaults.set(encoded, forKey: AppConstants.assessmentBatchLimitCompatibilityKey)
    }

    private func assessmentCompatibilityKey(endpointID: UUID, modelID: String) -> String {
        "\(endpointID.uuidString)|\(modelID)"
    }

    private func persistAssessmentPackage(
        _ package: AssessmentPackage,
        request: AssessmentRequest,
        kind: AssessmentKind,
        generatorModelID: String,
        reviewPlanID: UUID?
    ) throws -> AssessmentSession {
        let session = AssessmentSession(
            knowledgeNodeID: request.knowledgeNodeID,
            kind: kind,
            generatorModelID: generatorModelID,
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

        _ = try settleAssessmentResponse(session: session, item: item, response: response)
        return try advanceAssessmentSession(session)
    }

    func skipAssessmentItem(
        session: AssessmentSession,
        item: AssessmentItem
    ) throws -> AssessmentProgress {
        guard session.statusRawValue == "active" else { throw AssessmentFlowError.inactiveSession }
        guard item.sessionID == session.id else { throw AssessmentFlowError.missingItem }
        guard !assessmentResponses.contains(where: { $0.itemID == item.id }) else {
            throw AssessmentFlowError.duplicateResponse
        }
        let response = AssessmentResponse(
            item: item,
            selectedAnswerIndex: -1,
            selectedReasoningIndex: -1,
            usedAssistance: false
        )
        modelContext.insert(response)
        assessmentResponses.append(response)
        responsesBySessionID[session.id, default: []].append(response)

        // 记录跳过冷却，避免立即重新生成同一知识点题包
        let cooldownKey = "skippedAssessmentCooldown:\(item.knowledgeNodeID.uuidString)"
        automationDefaults.set(Date().timeIntervalSince1970, forKey: cooldownKey)

        // 跳过不产生 mastery observation，不改变 posterior，不结算 XP
        try modelContext.save()
        return try advanceAssessmentSession(session)
    }

    private func advanceAssessmentSession(_ session: AssessmentSession) throws -> AssessmentProgress {
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

        let defaultGrade: MemoryReviewGrade?
        if session.kind == .delayedReview {
            let allCorrect = sessionResponses.allSatisfy(\.isFullyCorrect) && sessionResponses.allSatisfy({ !$0.usedAssistance })
            defaultGrade = allCorrect ? .good : .again
        } else {
            defaultGrade = nil
        }
        try finalizeAssessment(session: session, reviewGrade: defaultGrade)
        return AssessmentProgress(nextItemID: nil, isCompleted: true, requiresReviewGrade: false)
    }

    func completeReviewAssessment(session: AssessmentSession, grade: MemoryReviewGrade) throws {
        guard session.kind == .delayedReview else {
            throw AssessmentFlowError.reviewGradeNotExpected
        }
        if session.statusRawValue == "completed" {
            try updateReviewGrade(sessionID: session.id, grade: grade)
        } else {
            try finalizeAssessment(session: session, reviewGrade: grade)
        }
    }

    func updateReviewGrade(sessionID: UUID, grade: MemoryReviewGrade) throws {
        guard let session = assessmentSessions.first(where: { $0.id == sessionID }) else { return }
        guard session.kind == .delayedReview else { return }
        let canonicalKey = "assessment:\(session.id.uuidString)"
        guard let event = memoryReviewEvents.first(where: { $0.canonicalKey == canonicalKey }) else { return }
        guard event.grade != grade else { return }
        event.grade = grade
        replayMemory(nodeID: session.knowledgeNodeID)
        if let memory = memoryByNodeID[session.knowledgeNodeID],
           let existingPlan = reviewPlans.first(where: {
               $0.knowledgeNodeID == session.knowledgeNodeID && ($0.status == "scheduled" || $0.status == "due")
           }) {
            existingPlan.scheduledAt = memory.nextReviewAt
            existingPlan.status = memory.nextReviewAt <= .now ? "due" : "scheduled"
        }
        try modelContext.save()
    }

    func invalidateAssessmentItem(_ item: AssessmentItem) throws {
        item.isInvalidated = true
        let affectedResponses = assessmentResponses.filter { $0.itemID == item.id }
        affectedResponses.forEach { $0.isInvalidated = true }
        let responseIDs = Set(affectedResponses.map(\.id))
        evidenceRecords
            .filter { evidence in responseIDs.contains { evidence.fingerprint.contains($0.uuidString) } }
            .forEach { $0.isVerified = false }
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

    @discardableResult
    private func settleAssessmentResponse(
        session: AssessmentSession,
        item: AssessmentItem,
        response: AssessmentResponse
    ) throws -> Int {
        guard !response.usedAssistance, !response.wasSkipped else {
            return 0
        }

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

        synchronizeMasteryProjection(nodeID: item.knowledgeNodeID)
        return 0
    }

    private func finalizeAssessment(
        session: AssessmentSession,
        reviewGrade: MemoryReviewGrade?
    ) throws {
        guard session.statusRawValue != "completed" else { return }
        let validResponses = responses(for: session.id).filter { !$0.isInvalidated }
        guard validResponses.count >= assessmentAdaptiveEngine.minimumResponseCount else {
            throw AssessmentFlowError.insufficientResponses
        }
        let responsePairs = validResponses.compactMap { response -> (AssessmentResponse, AssessmentItem)? in
            guard let item = assessmentItems.first(where: { $0.id == response.itemID }) else { return nil }
            return (response, item)
        }
        let measuredNodeIDs = Set(responsePairs.map { $0.1.knowledgeNodeID })
        guard !measuredNodeIDs.isEmpty else { throw AssessmentFlowError.missingItem }
        let measuredNodes = measuredNodeIDs.compactMap(node(for:))
        guard measuredNodes.count == measuredNodeIDs.count else { throw AppStateError.missingKnowledgeNode }
        let now = Date.now
        let isDomainAssessment = measuredNodes.count > 1
        let domainName = measuredNodes.first?.domain ?? "学习领域"

        let activity = ActivityEvent(
            sourceID: session.id,
            sourceKind: .manual,
            timestamp: now,
            fingerprint: "assessment-\(session.id.uuidString)",
            title: "主动验证 · \(domainName)",
            sourceLocator: "assessment/\(session.id.uuidString)",
            summary: "完成 \(validResponses.count) 题主动验证",
            excerpt: "",
            isProcessed: true
        )
        modelContext.insert(activity)
        activityEvents.insert(activity, at: 0)

        for node in measuredNodes {
            let nodeResponses = responsePairs.filter { $0.1.knowledgeNodeID == node.id }
            let nodeHasValidUnassisted = nodeResponses.contains { $0.0.isFullyCorrect && !$0.0.usedAssistance }
            let state = masteryByNodeID[node.id] ?? {
                let created = MasteryState(knowledgeNodeID: node.id)
                modelContext.insert(created)
                masteryStates.append(created)
                masteryByNodeID[node.id] = created
                return created
            }()

            let evidenceKind: EvidenceKind = switch session.kind {
            case .delayedReview: .review
            case .challenge, .production: .project
            case .baseline: .exercise
            }
            let isVerified = nodeHasValidUnassisted
            let evidence = EvidenceRecord(
                activityID: activity.id,
                knowledgeNodeID: node.id,
                kind: evidenceKind,
                timestamp: now,
                summary: "完成主动验证（覆盖 \(nodeResponses.count) 题）",
                rationale: "由预置情境与理由题本地判分形成的直接印证表现",
                difficulty: 1,
                independence: session.assistanceMode == .declaredUnassisted ? 1 : 0,
                aiConfidence: 1,
                isVerified: isVerified,
                fingerprint: "assessment-evidence-\(session.id.uuidString)-\(node.id.uuidString)",
                origin: .directAssessment,
                verificationLevel: .directChoice,
                assistanceMode: session.assistanceMode,
                assessmentSessionID: session.id
            )
            modelContext.insert(evidence)
            evidenceRecords.insert(evidence, at: 0)
            evidenceByID[evidence.id] = evidence
            evidenceByNodeID[node.id, default: []].insert(evidence, at: 0)

            synchronizeMasteryProjection(nodeID: node.id)

            // Confidence 基于 unique response 数量计算，不再按 observation 虚高
            let uniqueNodeResponses = Set((observationsByNodeID[node.id] ?? []).filter { !$0.isInvalidated }.map(\.responseID)).count
            state.confidence = min(100, Double(uniqueNodeResponses) / 3.0 * 100)

            let previousComposite = state.peakComposite
            let snapshot = readiness(for: node.id, now: now)
            let newComposite = snapshot?.currentComposite ?? state.vector.composite
            let xpGain = Int((max(0, newComposite - previousComposite) * 10).rounded())
            if xpGain > 0 && nodeHasValidUnassisted {
                state.peakComposite = max(state.peakComposite, newComposite)
                state.lifetimeXP += xpGain
            }

            if let certified = snapshot?.certifiedStage, certified.level > state.highestStage.level {
                state.highestStageRawValue = certified.rawValue
            }

            let ledger = ScoreLedgerEntry(
                evidenceID: evidence.id,
                knowledgeNodeID: node.id,
                timestamp: now,
                previousComposite: previousComposite,
                newComposite: newComposite,
                xpAwarded: xpGain,
                reason: "主动验证结算"
            )
            modelContext.insert(ledger)
            scoreLedgerEntries.insert(ledger, at: 0)
            ledgerByNodeID[node.id, default: []].append(ledger)

            if session.kind == .delayedReview, let reviewGrade {
                registerAssessmentReview(
                    session: session,
                    evidence: evidence,
                    grade: reviewGrade,
                    at: now
                )
            }
        }

        session.statusRawValue = "completed"
        session.completedAt = now
        try modelContext.save()
        refreshDerivedState()
        runTriggerEngine(now: now)
        let targetTitle = isDomainAssessment ? "\(domainName)领域" : "“\(measuredNodes[0].name)”"
        statusMessage = "已完成\(targetTitle)主动验证"
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
                reason: "FSRS 根据主动检索结果安排下一次复习",
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
        func value(_ dimension: MasteryDimension, current: Double) -> Double {
            let key = MasteryEstimate.key(nodeID: nodeID, dimension: dimension)
            if let estimate = masteryEstimateByTrackKey[key] {
                return estimate.probability * 100
            }
            return current
        }
        state.vector = MasteryVector(
            exposure: value(.exposure, current: state.vector.exposure),
            understanding: value(.understanding, current: state.vector.understanding),
            practice: value(.practice, current: state.vector.practice),
            retention: value(.retention, current: state.vector.retention),
            autonomy: value(.autonomy, current: state.vector.autonomy)
        )
        let lastObserved = observationsByNodeID[nodeID]?.filter({ !$0.isInvalidated }).map(\.observedAt).max()
        if let lastObserved {
            state.lastEvidenceAt = [state.lastEvidenceAt, lastObserved].compactMap { $0 }.max()
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}

private extension Double {
    var mapToProbability: Double { (self / 100).clamped(to: 0...1) }
}
