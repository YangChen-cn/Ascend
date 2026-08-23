import Foundation

struct AutomationPreferences: Equatable, Sendable {
    static let collectionEnabledKey = "automaticCollectionEnabled"
    static let collectionIntervalMinutesKey = "automaticCollectionIntervalMinutes"
    static let analysisPolicyKey = "automaticAnalysisPolicy"
    static let analysisThresholdKey = "automaticAnalysisPendingThreshold"
    static let lastAutomaticAnalysisAtKey = "lastAutomaticAnalysisAt"

    static let defaultCollectionIntervalMinutes = 10
    static let defaultAnalysisThreshold = 10

    let collectionEnabled: Bool
    let collectionIntervalMinutes: Int
    let analysisPolicy: AutomaticAnalysisPolicy
    let analysisThreshold: Int
    let lastAutomaticAnalysisAt: Date?

    static func current(defaults: UserDefaults = .standard) -> Self {
        let interval = defaults.integer(forKey: collectionIntervalMinutesKey)
        let threshold = defaults.integer(forKey: analysisThresholdKey)
        let rawPolicy = defaults.string(forKey: analysisPolicyKey)
        return Self(
            collectionEnabled: defaults.object(forKey: collectionEnabledKey) == nil
                ? true
                : defaults.bool(forKey: collectionEnabledKey),
            collectionIntervalMinutes: (interval == 0 ? defaultCollectionIntervalMinutes : interval)
                .clamped(to: 1...60),
            analysisPolicy: rawPolicy.flatMap(AutomaticAnalysisPolicy.init(rawValue:)) ?? .off,
            analysisThreshold: (threshold == 0 ? defaultAnalysisThreshold : threshold)
                .clamped(to: 1...100),
            lastAutomaticAnalysisAt: defaults.object(forKey: lastAutomaticAnalysisAtKey) as? Date
        )
    }
}
