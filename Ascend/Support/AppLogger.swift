import OSLog

enum AppLogger {
    static let app = Logger(subsystem: AppConstants.loggerSubsystem, category: "app")
    static let ai = Logger(subsystem: AppConstants.loggerSubsystem, category: "ai")
    static let collector = Logger(subsystem: AppConstants.loggerSubsystem, category: "collector")
    static let scoring = Logger(subsystem: AppConstants.loggerSubsystem, category: "scoring")
}
