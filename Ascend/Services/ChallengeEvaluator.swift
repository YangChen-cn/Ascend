import Foundation

struct ChallengeEvidenceSnapshot: Equatable, Sendable {
    let id: UUID
    let knowledgeNodeID: UUID
    let kind: EvidenceKind
    let timestamp: Date
    let independence: Double
    let confidence: Double
    let isVerified: Bool
    let verificationLevel: VerificationLevel
    let canonicalKey: String

    init(
        id: UUID,
        knowledgeNodeID: UUID,
        kind: EvidenceKind,
        timestamp: Date,
        independence: Double,
        confidence: Double,
        isVerified: Bool,
        verificationLevel: VerificationLevel = .productionRubric,
        canonicalKey: String? = nil
    ) {
        self.id = id
        self.knowledgeNodeID = knowledgeNodeID
        self.kind = kind
        self.timestamp = timestamp
        self.independence = independence
        self.confidence = confidence
        self.isVerified = isVerified
        self.verificationLevel = verificationLevel
        self.canonicalKey = canonicalKey ?? "evidence:\(id.uuidString)"
    }
}

struct ChallengeEvaluation: Equatable, Sendable {
    enum CompletionMode: String, Sendable {
        case knowledgeCheck
        case production
    }

    let isCompleted: Bool
    let matchedEvidenceIDs: [UUID]
    let completionMode: CompletionMode?
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
            return ChallengeEvaluation(isCompleted: false, matchedEvidenceIDs: [], completionMode: nil)
        }

        let eligibleGroups: [[ChallengeEvidenceSnapshot]] = EvidenceCanonicalizer.groups(evidence).compactMap { group in
            // 同一内容先在本地出现、后随 Git push 再出现时，其发生时间以最早 provenance 为准。
            // 因此接取挑战前已经发生的学习，不能靠后续同步副本满足挑战。
            guard group.occurredAt >= acceptedAt else { return nil }
            let eligible = group.evidence.filter {
                $0.isVerified &&
                    targetNodeIDs.contains($0.knowledgeNodeID) &&
                    $0.independence >= requirement.minimumIndependence &&
                    $0.confidence >= requirement.minimumConfidence
            }
            return eligible.isEmpty ? nil : eligible
        }

        let productionMatched = eligibleGroups.compactMap { group in
            group.first {
                $0.verificationLevel.isProductionPerformance &&
                    $0.kind.challengeRank >= requirement.minimumEvidenceKind.challengeRank
            }
        }
        if completes(
            productionMatched,
            targetNodeIDs: targetNodeIDs,
            requiredEvidenceCount: requirement.requiredEvidenceCount
        ) {
            return ChallengeEvaluation(
                isCompleted: true,
                matchedEvidenceIDs: productionMatched.map(\.id),
                completionMode: .production
            )
        }

        // 选择题是独立的低奖励知识验证路径，只能以练习级表现参与，绝不伪装成项目实作。
        let knowledgeCheckMatched = eligibleGroups.compactMap { group in
            group.first {
                $0.verificationLevel == .directChoice &&
                    $0.kind.challengeRank >= EvidenceKind.exercise.challengeRank
            }
        }
        let knowledgeCheckCompleted = completes(
            knowledgeCheckMatched,
            targetNodeIDs: targetNodeIDs,
            requiredEvidenceCount: requirement.requiredEvidenceCount
        )
        return ChallengeEvaluation(
            isCompleted: knowledgeCheckCompleted,
            matchedEvidenceIDs: knowledgeCheckCompleted
                ? knowledgeCheckMatched.map(\.id)
                : (productionMatched.isEmpty ? knowledgeCheckMatched.map(\.id) : productionMatched.map(\.id)),
            completionMode: knowledgeCheckCompleted ? .knowledgeCheck : nil
        )
    }

    private func completes(
        _ evidence: [ChallengeEvidenceSnapshot],
        targetNodeIDs: Set<UUID>,
        requiredEvidenceCount: Int
    ) -> Bool {
        Set(evidence.map(\.knowledgeNodeID)).isSuperset(of: targetNodeIDs) &&
            evidence.count >= requiredEvidenceCount
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
