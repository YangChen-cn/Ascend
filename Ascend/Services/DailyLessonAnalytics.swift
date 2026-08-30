import Foundation

/// 日课纯计算：星期调度、连续打卡、到期分桶与热力图聚合。
/// 全部函数以 `now` / `calendar` 入参注入，便于测试固定时间与时区；无副作用、不落库。
enum DailyLessonAnalytics {
    // MARK: - 星期调度

    /// weekdayMask：bit0 = 周日 … bit6 = 周六；0 表示每天重复。
    static func isWeekdayMaskScheduled(_ mask: Int, on day: Date, calendar: Calendar = .current) -> Bool {
        guard mask != 0 else { return true }
        let weekday = calendar.component(.weekday, from: day) // 1 = 周日
        return mask & (1 << (weekday - 1)) != 0
    }

    // MARK: - 连续打卡

    /// 从今天向前回溯"被调度且已完成"的自然日。
    /// 今天被调度但尚未完成时不计入也不中断（今天还有机会）；更早的调度日漏掉即断。
    static func habitStreak(
        completedDays: Set<Date>,
        weekdayMask: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        let today = cursor
        // 防御上限：10 年，正常路径早已因断签或无调度日返回。
        for _ in 0..<(366 * 10) {
            if isWeekdayMaskScheduled(weekdayMask, on: cursor, calendar: calendar) {
                if completedDays.contains(cursor) {
                    streak += 1
                } else if cursor < today {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// 历史最长连续打卡，用于热力图汇总；从最早一次完成日起扫描到今天。
    static func longestHabitStreak(
        completedDays: Set<Date>,
        weekdayMask: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard !completedDays.isEmpty else { return 0 }
        var longest = 0
        var current = 0
        var cursor = completedDays.min() ?? calendar.startOfDay(for: now)
        let today = calendar.startOfDay(for: now)
        while cursor <= today {
            if isWeekdayMaskScheduled(weekdayMask, on: cursor, calendar: calendar) {
                if completedDays.contains(cursor) {
                    current += 1
                    longest = max(longest, current)
                } else {
                    current = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return longest
    }

    // MARK: - 到期分桶

    static func dueBucket(for dueDate: Date?, now: Date, calendar: Calendar = .current) -> DailyTaskDueBucket {
        guard let dueDate else { return .undated }
        let day = calendar.startOfDay(for: dueDate)
        let today = calendar.startOfDay(for: now)
        if day < today { return .overdue }
        if day == today { return .today }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), day == tomorrow { return .tomorrow }
        return .upcoming
    }

    // MARK: - 热力图

    /// 聚合一页热力图：按周列组织（周一 → 周日），青玉完成数 + 是否存在真实采集活动。
    static func heatmap(
        weekCount: Int,
        completionCountsByDay: [Date: Int],
        activityDays: Set<Date>,
        now: Date,
        calendar: Calendar = .current
    ) -> DailyLessonHeatmapData {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7 // 1=周日 → 6，2=周一 → 0
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let firstColumnStart = calendar.date(byAdding: .day, value: -7 * (weekCount - 1), to: currentWeekStart) ?? today

        var columns: [[DailyLessonHeatmapCell]] = []
        var totalCompletions = 0
        var todayCompletions = 0
        for column in 0..<max(1, weekCount) {
            var cells: [DailyLessonHeatmapCell] = []
            for row in 0..<7 {
                guard
                    let day = calendar.date(
                        byAdding: .day,
                        value: column * 7 + row,
                        to: firstColumnStart
                    )
                else { continue }
                let normalizedDay = calendar.startOfDay(for: day)
                guard normalizedDay <= today else {
                    cells.append(DailyLessonHeatmapCell(day: normalizedDay, completionCount: 0, hasLearningActivity: false, isFuture: true))
                    continue
                }
                let count = completionCountsByDay[normalizedDay] ?? 0
                totalCompletions += count
                if normalizedDay == today { todayCompletions = count }
                cells.append(
                    DailyLessonHeatmapCell(
                        day: normalizedDay,
                        completionCount: count,
                        hasLearningActivity: activityDays.contains(normalizedDay),
                        isFuture: false
                    )
                )
            }
            columns.append(cells)
        }
        return DailyLessonHeatmapData(
            columns: columns,
            todayCompletions: todayCompletions,
            totalCompletions: totalCompletions
        )
    }
}

enum DailyTaskDueBucket: Equatable, Sendable {
    case overdue
    case today
    case tomorrow
    case upcoming
    case undated
}

struct DailyLessonHeatmapCell: Equatable, Identifiable, Sendable {
    let day: Date
    let completionCount: Int
    let hasLearningActivity: Bool
    let isFuture: Bool

    var id: Date { day }
}

struct DailyLessonHeatmapData: Equatable, Sendable {
    /// 每列一周（周一 → 周日）；最后一列为当前周。
    let columns: [[DailyLessonHeatmapCell]]
    let todayCompletions: Int
    let totalCompletions: Int

    static let empty = DailyLessonHeatmapData(columns: [], todayCompletions: 0, totalCompletions: 0)
}
