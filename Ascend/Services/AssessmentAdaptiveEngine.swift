import Foundation

struct AssessmentAdaptiveEngine: Sendable {
    let minimumResponseCount = 1
    let maximumResponseCount = 3

    /// 融会印证需要至少 2 个题目的独立全对表现；验证意图的 session 至少作答 2 题，
    /// 避免「答对了却不认证」。该最少题数由调用方按节点就绪状态计算后经
    /// `minimumResponses` 传入；默认 1 保持研习与复习意图的轻量体验。
    func startingTier(probability: Double?) -> AssessmentTier {
        guard let probability else { return .application }
        return switch probability {
        case ..<0.35: AssessmentTier.foundational
        case ..<0.65: AssessmentTier.application
        default: AssessmentTier.transfer
        }
    }

    func nextItem(
        from items: [AssessmentItem],
        presentedItemIDs: [UUID],
        responses: [AssessmentResponse],
        initialProbability: Double?,
        preferredTierByNodeID: [UUID: AssessmentTier] = [:],
        minimumResponses: Int = 1
    ) -> AssessmentItem? {
        let validResponses = responses.filter { !$0.isInvalidated }
        let effectiveMinimum = min(minimumResponses, maximumResponseCount)
        if validResponses.count >= maximumResponseCount || shouldStop(responses: responses, minimumResponses: effectiveMinimum) {
            return nil
        }
        let presented = Set(presentedItemIDs)
        let available = items.filter { !presented.contains($0.id) && !$0.isInvalidated }
        guard !available.isEmpty else { return nil }
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let answeredNodeIDs = Set(responses.compactMap { itemByID[$0.itemID]?.knowledgeNodeID })
        let allNodeIDs = Set(items.map(\.knowledgeNodeID))
        let uncoveredNodeIDs = allNodeIDs.subtracting(answeredNodeIDs)
        let targetTier: AssessmentTier
        if let lastResponse = responses.max(by: { $0.answeredAt < $1.answeredAt }),
           let lastItem = items.first(where: { $0.id == lastResponse.itemID }) {
            let delta = lastResponse.isFullyCorrect ? 1 : -1
            let targetLevel = (lastItem.tier.level + delta).clamped(to: 0...2)
            targetTier = AssessmentTier.allCases.first(where: { $0.level == targetLevel }) ?? lastItem.tier
        } else {
            targetTier = startingTier(probability: initialProbability)
        }
        let coverageCandidates = available.filter { uncoveredNodeIDs.contains($0.knowledgeNodeID) }
        let candidates = coverageCandidates.isEmpty ? available : coverageCandidates
        return candidates.min {
            let lhsTarget = preferredTierByNodeID[$0.knowledgeNodeID] ?? targetTier
            let rhsTarget = preferredTierByNodeID[$1.knowledgeNodeID] ?? targetTier
            let lhsDistance = abs($0.tier.level - lhsTarget.level)
            let rhsDistance = abs($1.tier.level - rhsTarget.level)
            return lhsDistance == rhsDistance ? $0.id.uuidString < $1.id.uuidString : lhsDistance < rhsDistance
        }
    }

    func shouldStop(responses: [AssessmentResponse], minimumResponses: Int = 1) -> Bool {
        let valid = responses.filter { !$0.isInvalidated }
        if valid.count >= maximumResponseCount { return true }
        let effectiveMinimum = min(minimumResponses, maximumResponseCount)
        guard valid.count >= effectiveMinimum else { return false }

        // 达到有效最少题数且独立全部答对（判断 + 理由），表现明确，可直接结束
        if valid.allSatisfy({ $0.isFullyCorrect && !$0.usedAssistance }) {
            return true
        }

        // 2 题如果表现一致（全对或全错），结论明确，可提前结束
        if valid.count == 2 {
            let allCorrect = valid.allSatisfy { $0.isFullyCorrect && !$0.usedAssistance }
            let allIncorrect = valid.allSatisfy { !$0.isFullyCorrect }
            if allCorrect || allIncorrect { return true }
        }

        return valid.count >= maximumResponseCount
    }
}
