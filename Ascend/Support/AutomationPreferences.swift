import Foundation

struct AutomationPreferences: Equatable, Sendable {
    static let collectionEnabledKey = "automaticCollectionEnabled"
    static let collectionIntervalMinutesKey = "automaticCollectionIntervalMinutes"
    static let analysisPolicyKey = "automaticAnalysisPolicy"
    static let analysisThresholdKey = "automaticAnalysisPendingThreshold"
    static let dailyAnalysisHourKey = "automaticDailyAnalysisHour"
    static let dailyAnalysisMinuteKey = "automaticDailyAnalysisMinute"
    static let lastAutomaticAnalysisAtKey = "lastAutomaticAnalysisAt"
    static let assessmentPreparationEnabledKey = "automaticAssessmentPreparationEnabled"

    static let defaultCollectionIntervalMinutes = 10
    static let defaultAnalysisThreshold = 10
    static let defaultDailyAnalysisHour = 21
    static let defaultDailyAnalysisMinute = 30
    static let defaultAssessmentPreparationEnabled = false

    let collectionEnabled: Bool
    let collectionIntervalMinutes: Int
    let analysisPolicy: AutomaticAnalysisPolicy
    let analysisThreshold: Int
    let dailyAnalysisHour: Int
    let dailyAnalysisMinute: Int
    let lastAutomaticAnalysisAt: Date?
    let assessmentPreparationEnabled: Bool

    static func current(defaults: UserDefaults = .standard) -> Self {
        let interval = defaults.integer(forKey: collectionIntervalMinutesKey)
        let threshold = defaults.integer(forKey: analysisThresholdKey)
        let rawPolicy = defaults.string(forKey: analysisPolicyKey)
        let storedHour = defaults.object(forKey: dailyAnalysisHourKey) as? Int
        let storedMinute = defaults.object(forKey: dailyAnalysisMinuteKey) as? Int
        return Self(
            collectionEnabled: defaults.object(forKey: collectionEnabledKey) == nil
                ? true
                : defaults.bool(forKey: collectionEnabledKey),
            collectionIntervalMinutes: (interval == 0 ? defaultCollectionIntervalMinutes : interval)
                .clamped(to: 1...60),
            analysisPolicy: rawPolicy.flatMap(AutomaticAnalysisPolicy.init(rawValue:)) ?? .off,
            analysisThreshold: (threshold == 0 ? defaultAnalysisThreshold : threshold)
                .clamped(to: 1...100),
            dailyAnalysisHour: (storedHour ?? defaultDailyAnalysisHour).clamped(to: 0...23),
            dailyAnalysisMinute: (storedMinute ?? defaultDailyAnalysisMinute).clamped(to: 0...59),
            lastAutomaticAnalysisAt: defaults.object(forKey: lastAutomaticAnalysisAtKey) as? Date,
            assessmentPreparationEnabled: defaults.bool(forKey: assessmentPreparationEnabledKey)
        )
    }
}
