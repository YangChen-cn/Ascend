import Foundation

struct MemoryTriggerSnapshot: Equatable, Sendable {
    let knowledgeNodeID: UUID
    let retrievability: Double
    let nextReviewAt: Date
    let reps: Int
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
        memory: [MemoryTriggerSnapshot],
        plans: [ReviewPlanTriggerSnapshot],
        evidence: [ChallengeEvidenceSnapshot],
        memoryReviewCanonicalKeys: Set<String>,
        now: Date
    ) -> [ReviewPlanTriggerAction] {
        var actions: [ReviewPlanTriggerAction] = []
        let activeStatuses = Set(["scheduled", "due"])
        let canonicalEvidence = EvidenceCanonicalizer.groups(evidence)

        var completingPlanIDs = Set<UUID>()
        for plan in plans where activeStatuses.contains(plan.status) {
            let completionEvidence = canonicalEvidence
                .filter {
                    $0.occurredAt >= plan.createdAt && memoryReviewCanonicalKeys.contains($0.key)
                }
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
                completingPlanIDs.insert(plan.id)
            } else if plan.status == "scheduled", plan.scheduledAt <= now {
                actions.append(.markDue(planID: plan.id))
            }
        }

        let activeNodeIDs = Set(plans.filter {
            activeStatuses.contains($0.status) && !completingPlanIDs.contains($0.id)
        }.map(\.knowledgeNodeID))
        for snapshot in memory where snapshot.reps > 0 && !activeNodeIDs.contains(snapshot.knowledgeNodeID) {
            let alreadyRepresented = plans.contains {
                $0.knowledgeNodeID == snapshot.knowledgeNodeID &&
                    abs($0.scheduledAt.timeIntervalSince(snapshot.nextReviewAt)) < 1
            }
            guard !alreadyRepresented else { continue }
            actions.append(
                .create(
                    knowledgeNodeID: snapshot.knowledgeNodeID,
                    scheduledAt: snapshot.nextReviewAt,
                    reason: "FSRS 预计记忆保持降至目标区间，建议按时温故"
                )
            )
        }
        return actions
    }
}
