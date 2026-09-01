import Foundation

struct ChallengeEvidenceSnapshot: Equatable, Sendable {
    let id: UUID
    let knowledgeNodeID: UUID
    let kind: EvidenceKind
    let timestamp: Date
    let independence: Double
    let confidence: Double
    let isVerified: Bool
    let canonicalKey: String

    init(
        id: UUID,
        knowledgeNodeID: UUID,
        kind: EvidenceKind,
        timestamp: Date,
        independence: Double,
        confidence: Double,
        isVerified: Bool,
        canonicalKey: String? = nil
    ) {
        self.id = id
        self.knowledgeNodeID = knowledgeNodeID
        self.kind = kind
        self.timestamp = timestamp
        self.independence = independence
        self.confidence = confidence
        self.isVerified = isVerified
        self.canonicalKey = canonicalKey ?? "evidence:\(id.uuidString)"
    }
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

        let matched: [ChallengeEvidenceSnapshot] = EvidenceCanonicalizer.groups(evidence).compactMap { group in
            // 同一内容先在本地出现、后随 Git push 再出现时，其发生时间以最早 provenance 为准。
            // 因此接取挑战前已经发生的学习，不能靠后续同步副本满足挑战。
            guard group.occurredAt >= acceptedAt else { return nil }
            return group.evidence.first {
                $0.isVerified &&
                    targetNodeIDs.contains($0.knowledgeNodeID) &&
                    $0.kind.challengeRank >= requirement.minimumEvidenceKind.challengeRank &&
                    $0.independence >= requirement.minimumIndependence &&
                    $0.confidence >= requirement.minimumConfidence
            }
        }
        let coveredNodeIDs = Set(matched.map(\.knowledgeNodeID))
        return ChallengeEvaluation(
            isCompleted: coveredNodeIDs.isSuperset(of: targetNodeIDs) &&
                matched.count >= requirement.requiredEvidenceCount,
            matchedEvidenceIDs: matched.map(\.id)
        )
    }
}

extension EvidenceKind {
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
