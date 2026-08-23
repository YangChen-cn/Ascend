import Foundation

struct ChallengeEvidenceSnapshot: Equatable, Sendable {
    let id: UUID
    let knowledgeNodeID: UUID
    let kind: EvidenceKind
    let timestamp: Date
    let independence: Double
    let confidence: Double
    let isVerified: Bool
}

struct ChallengeEvaluation: Equatable, Sendable {
    let isCompleted: Bool
    let matchedEvidenceIDs: [UUID]
}

struct ChallengeEvaluator: Sendable {
    func evaluate(
        targetNodeIDs: Set<UUID>,
        requirement: ChallengeRequirement,
        acceptedAt: Date,
        currentMasteryByNodeID: [UUID: Double],
        evidence: [ChallengeEvidenceSnapshot]
    ) -> ChallengeEvaluation {
        guard !targetNodeIDs.isEmpty,
              targetNodeIDs.allSatisfy({ currentMasteryByNodeID[$0, default: 0] >= requirement.minimumMastery }) else {
            return ChallengeEvaluation(isCompleted: false, matchedEvidenceIDs: [])
        }

        let matched = evidence.filter {
            $0.isVerified &&
                targetNodeIDs.contains($0.knowledgeNodeID) &&
                $0.timestamp >= acceptedAt &&
                $0.kind.challengeRank >= requirement.minimumEvidenceKind.challengeRank &&
                $0.independence >= requirement.minimumIndependence &&
                $0.confidence >= requirement.minimumConfidence
        }
        let coveredNodeIDs = Set(matched.map(\.knowledgeNodeID))
        return ChallengeEvaluation(
            isCompleted: coveredNodeIDs.isSuperset(of: targetNodeIDs) &&
                matched.count >= requirement.requiredEvidenceCount,
            matchedEvidenceIDs: matched.map(\.id)
        )
    }
}

private extension EvidenceKind {
    var challengeRank: Int {
        switch self {
        case .exposure: 0
        case .explanation: 1
        case .exercise, .review: 2
        case .project: 3
        case .independentSolve: 4
        }
    }
}
