import XCTest
@testable import Ascend

final class DailyLessonAnalyticsTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUpWithError() throws {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = gregorian
        now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 15)))
    }

    private func day(_ offset: Int) throws -> Date {
        try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: now))
    }

    // MARK: - 星期调度

    func testZeroMaskMeansDailySchedule() {
        XCTAssertTrue(DailyLessonAnalytics.isWeekdayMaskScheduled(0, on: now, calendar: calendar))
    }

    func testWeekdayMaskOnlyMatchesItsOwnWeekday() throws {
        let anchorWeekday = calendar.component(.weekday, from: now)
        let mask = 1 << (anchorWeekday - 1)
        XCTAssertTrue(DailyLessonAnalytics.isWeekdayMaskScheduled(mask, on: now, calendar: calendar))
        XCTAssertFalse(
            DailyLessonAnalytics.isWeekdayMaskScheduled(mask, on: try day(1), calendar: calendar),
            "相邻的另一天不应命中同一位掩码"
        )
    }

    // MARK: - 连续打卡

    func testStreakCountsTodayWhenCompleted() throws {
        let completed: Set<Date> = [calendar.startOfDay(for: now)]
        let streak = DailyLessonAnalytics.habitStreak(
            completedDays: completed, weekdayMask: 0, now: now, calendar: calendar
        )
        XCTAssertEqual(streak, 1)
    }

    func testPendingTodayDoesNotBreakStreakFromYesterday() throws {
        let completed: Set<Date> = [calendar.startOfDay(for: try day(-1)), calendar.startOfDay(for: try day(-2))]
        let streak = DailyLessonAnalytics.habitStreak(
            completedDays: completed, weekdayMask: 0, now: now, calendar: calendar
        )
        XCTAssertEqual(streak, 2, "今天尚未打卡时不得断签，也不得把今天计入")
    }

    func testMissedScheduledDayBreaksStreak() throws {
        let completed: Set<Date> = [calendar.startOfDay(for: try day(-1)), calendar.startOfDay(for: try day(-3))]
        let streak = DailyLessonAnalytics.habitStreak(
            completedDays: completed, weekdayMask: 0, now: now, calendar: calendar
        )
        XCTAssertEqual(streak, 1, "昨天完成、前天漏掉：连续数止于昨天")
    }

    func testUnscheduledDaysNeitherCountNorBreak() throws {
        let anchorWeekday = calendar.component(.weekday, from: now)
        let mask = 1 << (anchorWeekday - 1) // 仅在锚点星期重复
        let lastWeekSameWeekday = try day(-7)
        let streak = DailyLessonAnalytics.habitStreak(
            completedDays: [calendar.startOfDay(for: lastWeekSameWeekday)],
            weekdayMask: mask,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(streak, 1, "上周同星期完成 + 今天尚未打卡：连续数应为 1 且不断签")
    }

    func testLongestStreakTracksHistoricalMaximum() throws {
        let completed: Set<Date> = [
            calendar.startOfDay(for: try day(-1)),
            calendar.startOfDay(for: try day(-2)),
            calendar.startOfDay(for: try day(-3)),
            calendar.startOfDay(for: try day(-9))
        ]
        let longest = DailyLessonAnalytics.longestHabitStreak(
            completedDays: completed, weekdayMask: 0, now: now, calendar: calendar
        )
        XCTAssertEqual(longest, 3)
    }

    // MARK: - 到期分桶

    func testDueBuckets() throws {
        XCTAssertEqual(DailyLessonAnalytics.dueBucket(for: nil, now: now, calendar: calendar), .undated)
        XCTAssertEqual(
            DailyLessonAnalytics.dueBucket(for: try day(-1), now: now, calendar: calendar),
            .overdue
        )
        XCTAssertEqual(DailyLessonAnalytics.dueBucket(for: now, now: now, calendar: calendar), .today)
        XCTAssertEqual(
            DailyLessonAnalytics.dueBucket(for: try day(1), now: now, calendar: calendar),
            .tomorrow
        )
        XCTAssertEqual(
            DailyLessonAnalytics.dueBucket(for: try day(5), now: now, calendar: calendar),
            .upcoming
        )
    }

    // MARK: - 热力图

    func testHeatmapColumnsAlignToMondayAndMarkFuture() throws {
        let completions = [
            calendar.startOfDay(for: now): 3,
            calendar.startOfDay(for: try day(-1)): 1
        ]
        let data = DailyLessonAnalytics.heatmap(
            weekCount: 4,
            completionCountsByDay: completions,
            activityDays: [calendar.startOfDay(for: try day(-1))],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(data.columns.count, 4)
        XCTAssertEqual(data.columns.flatMap { $0 }.count, 28)
        XCTAssertEqual(data.todayCompletions, 3)
        XCTAssertEqual(data.totalCompletions, 4)

        let todayCell = data.columns.flatMap { $0 }.first { $0.day == calendar.startOfDay(for: now) }
        XCTAssertEqual(todayCell?.completionCount, 3)
        XCTAssertEqual(todayCell?.hasLearningActivity, false)

        let yesterday = calendar.startOfDay(for: try day(-1))
        let yesterdayCell = data.columns.flatMap { $0 }.first { $0.day == yesterday }
        XCTAssertEqual(yesterdayCell?.completionCount, 1)
        XCTAssertEqual(yesterdayCell?.hasLearningActivity, true, "存在真实采集活动的日子应带暖金标记")

        // 第一列必从周一开始
        let firstColumnDay = try XCTUnwrap(data.columns.first?.first?.day)
        XCTAssertEqual(calendar.component(.weekday, from: firstColumnDay), 2, "热力图列应从周一开始（weekday=2）")

        let futureCells = data.columns.flatMap { $0 }.filter { $0.isFuture }
        XCTAssertTrue(futureCells.allSatisfy { $0.completionCount == 0 && !$0.hasLearningActivity })
        XCTAssertTrue(futureCells.contains { $0.day > calendar.startOfDay(for: now) })
    }
}
