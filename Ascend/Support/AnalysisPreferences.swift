import Foundation

struct AnalysisPreferences: Equatable {
    static let batchSizeKey = "analysisBatchSize"
    static let maximumKnowledgePointsKey = "maximumKnowledgePointsPerActivity"
    static let repairsMalformedOutputKey = "repairsMalformedOutput"
    static let scansBeforeAnalysisKey = "scansBeforeAnalysis"

    let batchSize: Int
    let maximumKnowledgePointsPerActivity: Int
    let repairsMalformedOutput: Bool
    let scansBeforeAnalysis: Bool

    @MainActor
    static func current(defaults: UserDefaults = .standard) -> Self {
        let storedBatchSize = defaults.integer(forKey: batchSizeKey)
        let storedMaximum = defaults.integer(forKey: maximumKnowledgePointsKey)
        return Self(
            batchSize: (storedBatchSize == 0 ? AppConstants.defaultAnalysisBatchSize : storedBatchSize)
                .clamped(to: 1...20),
            maximumKnowledgePointsPerActivity: (storedMaximum == 0 ? AppConstants.defaultMaximumKnowledgePointsPerActivity : storedMaximum)
                .clamped(to: 1...5),
            repairsMalformedOutput: defaults.object(forKey: repairsMalformedOutputKey) == nil
                ? true
                : defaults.bool(forKey: repairsMalformedOutputKey),
            scansBeforeAnalysis: defaults.object(forKey: scansBeforeAnalysisKey) == nil
                ? true
                : defaults.bool(forKey: scansBeforeAnalysisKey)
        )
    }

    var options: AnalysisOptions {
        AnalysisOptions(
            maximumKnowledgePointsPerActivity: maximumKnowledgePointsPerActivity,
            repairsMalformedOutput: repairsMalformedOutput
        )
    }
}
