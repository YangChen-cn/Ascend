import Foundation

struct AnalysisOptions: Sendable, Equatable {
    let maximumKnowledgePointsPerActivity: Int
    let repairsMalformedOutput: Bool

    static let defaults = Self(
        maximumKnowledgePointsPerActivity: AppConstants.defaultMaximumKnowledgePointsPerActivity,
        repairsMalformedOutput: true
    )
}
