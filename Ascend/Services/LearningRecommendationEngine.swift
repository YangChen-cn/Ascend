import Foundation

struct LearningRecommendationEngine: Sendable {
    func recommendations(
        knowledge: [RecommendationKnowledgeSnapshot],
        challenges: [RecommendationChallengeSnapshot],
        now: Date,
        prerequisiteProvider: (any PrerequisiteReadinessProviding)? = nil,
        limit: Int = 3
    ) -> [LearningRecommendation] {
        let challengeByNodeID = challenges
            .filter { $0.status == "available" || $0.status == "in_progress" }
            .reduce(into: [UUID: RecommendationChallengeSnapshot]()) { result, challenge in
                for nodeID in challenge.knowledgeNodeIDs where result[nodeID] == nil {
                    result[nodeID] = challenge
                }
            }

        let candidates = knowledge.compactMap { snapshot in
            bestRecommendation(
                for: snapshot,
                challenge: challengeByNodeID[snapshot.id],
                now: now,
                prerequisiteProvider: prerequisiteProvider
            )
        }

        return Array(candidates.sorted(by: stablePriorityOrder).prefix(max(0, limit)))
    }

    private func bestRecommendation(
        for snapshot: RecommendationKnowledgeSnapshot,
        challenge: RecommendationChallengeSnapshot?,
        now: Date,
        prerequisiteProvider: (any PrerequisiteReadinessProviding)?
    ) -> LearningRecommendation? {
        let isPrerequisiteBlocked: Bool
        if case .blocked = prerequisiteProvider?.readiness(for: snapshot.id) {
            isPrerequisiteBlocked = true
        } else {
            isPrerequisiteBlocked = false
        }

        var candidates: [LearningRecommendation] = []
        if let review = reviewRecommendation(for: snapshot, now: now) {
            candidates.append(review)
        }

        let hasLearningHistory = snapshot.mastery.exposure > 0 || snapshot.recentEvidenceCount > 0
        if hasLearningHistory {
            if let practice = practiceRecommendation(for: snapshot) {
                candidates.append(practice)
            }
            if let challenge, let recommendation = challengeRecommendation(for: snapshot, challenge: challenge) {
                candidates.append(recommendation)
            }
            if let continuation = continueRecommendation(for: snapshot, now: now) {
                candidates.append(continuation)
            }
        }

        if !isPrerequisiteBlocked, let nextConcept = nextConceptRecommendation(for: snapshot) {
            candidates.append(nextConcept)
        }

        return candidates.sorted(by: stablePriorityOrder).first
    }

    private func nextConceptRecommendation(
        for snapshot: RecommendationKnowledgeSnapshot
    ) -> LearningRecommendation? {
        guard snapshot.isReadyToLearn, snapshot.satisfiedPrerequisitesCount > 0 else { return nil }
        guard snapshot.mastery.composite < 30 else { return nil }
        return LearningRecommendation(
            knowledgeNodeID: snapshot.id,
            type: .nextConcept,
            priority: 550 + Double(min(4, snapshot.satisfiedPrerequisitesCount) * 15),
            title: "下一境 · \(snapshot.name)",
            reason: "前置知识已具备，建议开始探索。",
            relevantMetrics: [
                LearningRecommendationMetric(name: "先导满足", value: Double(snapshot.satisfiedPrerequisitesCount), unit: "项")
            ],
            reviewPlanID: nil,
            challengeID: nil
        )
    }

    private func reviewRecommendation(
        for snapshot: RecommendationKnowledgeSnapshot,
        now: Date
    ) -> LearningRecommendation? {
        guard let retrievability = snapshot.retrievability else { return nil }
        let retention = (retrievability * 100).clamped(to: 0...100)
        let overdueSeconds = snapshot.reviewScheduledAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        let isDue = snapshot.reviewScheduledAt.map { $0 <= now } ?? false
        guard isDue || retention < 70 else { return nil }

        let risk = 100 - retention
        let overdueDays = overdueSeconds / 86_400
        let priority = 1_000 + risk * 2 + min(100, overdueDays * 8)
        let reason = isDue
            ? "记忆保持率已降至 \(Int(retention.rounded()))%，且复习已到期。"
            : "记忆保持率已降至 \(Int(retention.rounded()))%，已接近遗忘风险区。"
        return LearningRecommendation(
            knowledgeNodeID: snapshot.id,
            type: .review,
            priority: priority,
            title: snapshot.name,
            reason: reason,
            relevantMetrics: [
                LearningRecommendationMetric(name: "记忆", value: retention, unit: "%"),
                LearningRecommendationMetric(name: "逾期", value: overdueDays, unit: "天")
            ],
            reviewPlanID: snapshot.activeReviewPlanID,
            challengeID: nil
        )
    }

    private func practiceRecommendation(
        for snapshot: RecommendationKnowledgeSnapshot
    ) -> LearningRecommendation? {
        let weakest = min(snapshot.mastery.practice, snapshot.mastery.autonomy)
        let gap = snapshot.mastery.understanding - weakest
        guard snapshot.mastery.understanding >= 35, gap >= 15 else { return nil }
        let dimension = snapshot.mastery.practice <= snapshot.mastery.autonomy ? "实践" : "自主"
        let value = dimension == "实践" ? snapshot.mastery.practice : snapshot.mastery.autonomy
        return LearningRecommendation(
            knowledgeNodeID: snapshot.id,
            type: .practice,
            priority: 700 + gap * 2 + snapshot.mastery.understanding * 0.2,
            title: snapshot.name,
            reason: "理解 \(Int(snapshot.mastery.understanding.rounded()))，但实践仅 \(Int(snapshot.mastery.practice.rounded()))、自主仅 \(Int(snapshot.mastery.autonomy.rounded()))，当前主要短板是\(dimension)。",
            relevantMetrics: [
                LearningRecommendationMetric(name: "理解", value: snapshot.mastery.understanding, unit: ""),
                LearningRecommendationMetric(name: dimension, value: value, unit: "")
            ],
            reviewPlanID: nil,
            challengeID: nil
        )
    }

    private func challengeRecommendation(
        for snapshot: RecommendationKnowledgeSnapshot,
        challenge: RecommendationChallengeSnapshot
    ) -> LearningRecommendation? {
        let composite = snapshot.mastery.composite
        guard composite >= 30 else { return nil }
        return LearningRecommendation(
            knowledgeNodeID: snapshot.id,
            type: .challenge,
            priority: 620 + min(100, composite),
            title: snapshot.name,
            reason: "当前掌握 \(Int(composite.rounded()))，已有可由真实实据验证的试炼“\(challenge.title)”。",
            relevantMetrics: [
                LearningRecommendationMetric(name: "掌握", value: composite, unit: "")
            ],
            reviewPlanID: nil,
            challengeID: challenge.id
        )
    }

    private func continueRecommendation(
        for snapshot: RecommendationKnowledgeSnapshot,
        now: Date
    ) -> LearningRecommendation? {
        guard snapshot.recentEvidenceCount >= 2,
              let lastEvidenceAt = snapshot.lastEvidenceAt,
              now.timeIntervalSince(lastEvidenceAt) <= 7 * 86_400 else { return nil }
        return LearningRecommendation(
            knowledgeNodeID: snapshot.id,
            type: .continue,
            priority: 300 + Double(snapshot.recentEvidenceCount * 12),
            title: snapshot.name,
            reason: "近 7 天已有 \(snapshot.recentEvidenceCount) 条已验证实据，可延续当前学习脉络。",
            relevantMetrics: [
                LearningRecommendationMetric(name: "近期实据", value: Double(snapshot.recentEvidenceCount), unit: "条")
            ],
            reviewPlanID: nil,
            challengeID: nil
        )
    }

    private func stablePriorityOrder(
        _ lhs: LearningRecommendation,
        _ rhs: LearningRecommendation
    ) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        if lhs.type.rawValue != rhs.type.rawValue { return lhs.type.rawValue < rhs.type.rawValue }
        return lhs.knowledgeNodeID.uuidString < rhs.knowledgeNodeID.uuidString
    }
}
