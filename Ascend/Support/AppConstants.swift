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
}
