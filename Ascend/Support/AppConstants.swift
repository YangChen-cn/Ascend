import Foundation

enum AppConstants {
    static let bundleIdentifier = "com.yang.Ascend"
    static let loggerSubsystem = "com.yang.Ascend"
    static let defaultDigestHour = 21
    static let defaultDigestMinute = 30
    static let endpointTimeout: TimeInterval = 120
    static let analysisTimeout: TimeInterval = 180
    static let defaultAnalysisBatchSize = 10
    static let defaultMaximumKnowledgePointsPerActivity = 3
    static let maximumAuditExcerptLength = 2_000
    static let maximumLLMExcerptLength = 800
    static let maximumAssessmentTargetsPerPackage = 5
    static let maximumAssessmentTargetsPerRequest = 10
    static let maximumAssessmentSourceMaterialsPerPackage = 6
    static let maximumAssessmentSourceTitleLength = 160
    static let maximumAssessmentSourceSummaryLength = 400
    static let maximumAssessmentSourceExcerptLength = 800
    static let automaticAssessmentRetryInterval: TimeInterval = 6 * 60 * 60
    static let lastAutomaticAssessmentPreparationAttemptKey = "lastAutomaticAssessmentPreparationAttemptAt"
    static let measurementSystemVersionKey = "measurementSystemVersion"
    // Version 2 could be acknowledged before the user saw the migration prompt.
    // Bump once so affected installations are offered the explicit reset again.
    static let currentMeasurementSystemVersion = 3
}
