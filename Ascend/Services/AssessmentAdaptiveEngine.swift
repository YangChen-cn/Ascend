import Foundation

struct AssessmentAdaptiveEngine: Sendable {
    let minimumResponseCount = 3
    let maximumResponseCount = 5

    func startingTier(probability: Double?) -> AssessmentTier {
        guard let probability else { return .foundational }
        return switch probability {
        case ..<0.40: AssessmentTier.foundational
        case ..<0.70: AssessmentTier.application
        default: AssessmentTier.transfer
        }
    }

    func nextItem(
        from items: [AssessmentItem],
        presentedItemIDs: [UUID],
        responses: [AssessmentResponse],
        initialProbability: Double?,
        preferredTierByNodeID: [UUID: AssessmentTier] = [:]
    ) -> AssessmentItem? {
        let presented = Set(presentedItemIDs)
        let available = items.filter { !presented.contains($0.id) && !$0.isInvalidated }
        guard !available.isEmpty else { return nil }
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let answeredNodeIDs = Set(responses.compactMap { itemByID[$0.itemID]?.knowledgeNodeID })
        let allNodeIDs = Set(items.map(\.knowledgeNodeID))
        let uncoveredNodeIDs = allNodeIDs.subtracting(answeredNodeIDs)
        if shouldStop(responses: responses) && uncoveredNodeIDs.isEmpty { return nil }
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

    func shouldStop(responses: [AssessmentResponse]) -> Bool {
        let valid = responses.filter { !$0.isInvalidated }
        if valid.count >= maximumResponseCount { return true }
        guard valid.count >= minimumResponseCount else { return false }
        let recent = valid.sorted { $0.answeredAt < $1.answeredAt }.suffix(3)
        return recent.allSatisfy(\.isFullyCorrect) || recent.allSatisfy { !$0.isFullyCorrect }
    }
}
