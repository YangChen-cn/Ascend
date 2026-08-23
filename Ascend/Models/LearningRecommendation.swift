import Foundation

struct LearningRecommendation: Identifiable, Equatable, Sendable {
    let knowledgeNodeID: UUID
    let type: LearningRecommendationType
    let priority: Double
    let title: String
    let reason: String
    let relevantMetrics: [LearningRecommendationMetric]
    let reviewPlanID: UUID?
    let challengeID: UUID?

    var id: String {
        "\(type.rawValue):\(knowledgeNodeID.uuidString):\(reviewPlanID?.uuidString ?? "-"):\(challengeID?.uuidString ?? "-")"
    }
}
