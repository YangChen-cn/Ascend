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
    let isReadyToLearn: Bool
    let satisfiedPrerequisitesCount: Int

    init(
        id: UUID,
        name: String,
        mastery: MasteryVector,
        retrievability: Double?,
        activeReviewPlanID: UUID?,
        reviewScheduledAt: Date?,
        recentEvidenceCount: Int,
        lastEvidenceAt: Date?,
        isReadyToLearn: Bool = false,
        satisfiedPrerequisitesCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.mastery = mastery
        self.retrievability = retrievability
        self.activeReviewPlanID = activeReviewPlanID
        self.reviewScheduledAt = reviewScheduledAt
        self.recentEvidenceCount = recentEvidenceCount
        self.lastEvidenceAt = lastEvidenceAt
        self.isReadyToLearn = isReadyToLearn
        self.satisfiedPrerequisitesCount = satisfiedPrerequisitesCount
    }
}
