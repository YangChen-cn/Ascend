import Foundation

struct RecommendationKnowledgeSnapshot: Sendable {
    let id: UUID
    let name: String
    let mastery: MasteryVector
    let retrievability: Double?
    let activeReviewPlanID: UUID?
    let reviewScheduledAt: Date?
    let recentEvidenceCount: Int
    let lastEvidenceAt: Date?
}
