import Foundation

actor AnalysisScheduler {
    typealias AnalysisOperation = @MainActor @Sendable () async -> Bool

    private var isRunning = false

    func runIfNeeded(
        policy: AutomaticAnalysisPolicy,
        pendingCount: Int,
        threshold: Int,
        dailyHour: Int,
        dailyMinute: Int,
        lastRunAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current,
        operation: @escaping AnalysisOperation
    ) async -> Bool {
        guard !isRunning,
              Self.shouldRun(
                policy: policy,
                pendingCount: pendingCount,
                threshold: threshold,
                dailyHour: dailyHour,
                dailyMinute: dailyMinute,
                lastRunAt: lastRunAt,
                now: now,
                calendar: calendar
              ) else { return false }

        isRunning = true
        defer { isRunning = false }
        return await operation()
    }

    nonisolated static func shouldRun(
        policy: AutomaticAnalysisPolicy,
        pendingCount: Int,
        threshold: Int,
        dailyHour: Int,
        dailyMinute: Int,
        lastRunAt: Date?,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard pendingCount > 0 else { return false }
        switch policy {
        case .off:
            return false
        case .daily:
            guard let scheduledTime = calendar.date(
                bySettingHour: dailyHour.clamped(to: 0...23),
                minute: dailyMinute.clamped(to: 0...59),
                second: 0,
                of: now
            ), now >= scheduledTime else { return false }
            guard let lastRunAt else { return true }
            return !calendar.isDate(lastRunAt, inSameDayAs: now)
        case .pendingThreshold:
            return pendingCount >= max(1, threshold)
        }
    }
}
