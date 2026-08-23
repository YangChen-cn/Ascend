import Foundation

struct RetentionTriggerSnapshot: Equatable, Sendable {
    let knowledgeNodeID: UUID
    let historicalRetention: Double
    let currentRetention: Double
    let lastEvidenceAt: Date?
}

struct ReviewPlanTriggerSnapshot: Equatable, Sendable {
    let id: UUID
    let knowledgeNodeID: UUID
    let createdAt: Date
    let scheduledAt: Date
    let status: String
}

enum ReviewPlanTriggerAction: Equatable, Sendable {
    case markDue(planID: UUID)
    case complete(planID: UUID, evidenceID: UUID)
    case create(knowledgeNodeID: UUID, scheduledAt: Date, reason: String)
}

struct TriggerEngine: Sendable {
    func reviewPlanActions(
        retention: [RetentionTriggerSnapshot],
        plans: [ReviewPlanTriggerSnapshot],
        evidence: [ChallengeEvidenceSnapshot],
        now: Date
    ) -> [ReviewPlanTriggerAction] {
        var actions: [ReviewPlanTriggerAction] = []
        let activeStatuses = Set(["scheduled", "due"])
        let canonicalEvidence = EvidenceCanonicalizer.groups(evidence)

        for plan in plans where activeStatuses.contains(plan.status) {
            let completionEvidence = canonicalEvidence
                .filter { $0.occurredAt >= plan.createdAt }
                .compactMap { group in
                    group.evidence.first {
                        $0.isVerified &&
                            $0.knowledgeNodeID == plan.knowledgeNodeID &&
                            ($0.kind == .review || $0.kind == .exercise)
                    }
                }
                .min { $0.timestamp < $1.timestamp }
            if let completionEvidence {
                actions.append(.complete(planID: plan.id, evidenceID: completionEvidence.id))
            } else if plan.status == "scheduled", plan.scheduledAt <= now {
                actions.append(.markDue(planID: plan.id))
            }
        }

        let activeNodeIDs = Set(plans.filter { activeStatuses.contains($0.status) }.map(\.knowledgeNodeID))
        for snapshot in retention where
            snapshot.lastEvidenceAt != nil &&
            snapshot.historicalRetention - snapshot.currentRetention >= 10 &&
            !activeNodeIDs.contains(snapshot.knowledgeNodeID) {
            actions.append(
                .create(
                    knowledgeNodeID: snapshot.knowledgeNodeID,
                    scheduledAt: now,
                    reason: "记忆保持由 \(Int(snapshot.historicalRetention.rounded())) 降至 \(Int(snapshot.currentRetention.rounded()))，需要温故"
                )
            )
        }
        return actions
    }
}
