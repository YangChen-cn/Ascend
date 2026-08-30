import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class DailyLessonStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var calendar: Calendar!
    private var now: Date!

    override func setUpWithError() throws {
        container = PersistenceController.makeContainer(inMemory: true)
        suiteName = "DailyLessonStoreTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        appState = AppState(modelContainer: container, automationDefaults: defaults)
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = gregorian
        now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 10)))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func day(_ offset: Int) throws -> Date {
        try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: now))
    }

    // MARK: - 待办

    func testAddTodoTrimsTitleAndNormalizesDueDate() throws {
        let task = try XCTUnwrap(appState.addDailyTask(
            title: "  阅读 Swift 并发文档  ",
            dueDate: try day(2),
            now: now,
            calendar: calendar
        ))
        XCTAssertEqual(task.title, "阅读 Swift 并发文档")
        XCTAssertEqual(task.kind, .todo)
        XCTAssertEqual(appState.dailyTaskByID[task.id]?.dueDate, calendar.startOfDay(for: try day(2)))
        XCTAssertNil(task.completedAt)
    }

    func testAddTodoRejectsBlankTitle() {
        XCTAssertNil(appState.addDailyTask(title: "   ", now: now))
        XCTAssertTrue(appState.dailyTasks.isEmpty)
    }

    func testToggleTodoCompletesAndUndoes() throws {
        let task = try XCTUnwrap(appState.addDailyTask(title: "整理笔记", now: now))
        appState.toggleTodo(task, now: now)
        XCTAssertNotNil(task.completedAt)

        appState.toggleTodo(task, now: now)
        XCTAssertNil(task.completedAt, "再次勾选应撤销完成")
    }

    func testTodayTodoGroupsOrderOverdueFirstAndCompletedExcluded() throws {
        let overdue = appState.addDailyTask(title: "逾期任务", dueDate: try day(-1), now: try day(-2), calendar: calendar)
        let undated = appState.addDailyTask(title: "不限日任务", now: now)
        let today = appState.addDailyTask(title: "今日任务", dueDate: now, now: now, calendar: calendar)
        let done = appState.addDailyTask(title: "已完成任务", now: now)
        appState.toggleTodo(try XCTUnwrap(done), now: now)

        let groups = appState.todayTodoGroups(now: now, calendar: calendar)
        XCTAssertEqual(groups.open.map(\.title), ["逾期任务", "今日任务", "不限日任务"])
        XCTAssertTrue(groups.completed.contains(where: { $0.id == done?.id }))
        XCTAssertEqual(groups.open.count, 3)
    }

    func testUpcomingTodosOnlyContainFutureUnfinished() throws {
        _ = appState.addDailyTask(title: "未来任务", dueDate: try day(3), now: now, calendar: calendar)
        _ = appState.addDailyTask(title: "今日任务", now: now)
        let futureDone = appState.addDailyTask(title: "未来已完成", dueDate: try day(3), now: now, calendar: calendar)
        appState.toggleTodo(try XCTUnwrap(futureDone), now: now)

        let upcoming = appState.upcomingTodos(now: now, calendar: calendar)
        XCTAssertEqual(upcoming.map(\.title), ["未来任务"])
    }

    // MARK: - 习惯打卡

    func testHabitCheckInIsIdempotentPerDay() throws {
        let habit = try XCTUnwrap(appState.addDailyTask(
            title: "晨读",
            kind: .habit,
            weekdayMask: 0,
            now: now
        ))
        appState.completeHabit(habit, on: now, now: now, calendar: calendar)
        appState.completeHabit(habit, on: now, now: try day(0).addingTimeInterval(3_600), calendar: calendar)

        XCTAssertEqual(appState.dailyTaskLogs.count, 1, "同一自然日重复打卡必须幂等")
        XCTAssertTrue(appState.isHabitCompletedToday(habit, now: now, calendar: calendar))
    }

    func testHabitRejectsBackdatedCheckIn() throws {
        let habit = try XCTUnwrap(appState.addDailyTask(title: "晨读", kind: .habit, now: now))
        appState.completeHabit(habit, on: try day(-1), now: now, calendar: calendar)

        XCTAssertTrue(appState.dailyTaskLogs.isEmpty, "不允许补打卡")
        XCTAssertNotNil(appState.statusMessage)
    }

    func testToggleHabitRoundTrip() throws {
        let habit = try XCTUnwrap(appState.addDailyTask(title: "晨读", kind: .habit, now: now))
        appState.toggleHabit(habit, now: now, calendar: calendar)
        XCTAssertEqual(appState.dailyTaskLogs.count, 1)
        XCTAssertEqual(appState.habitStreak(for: habit, now: now, calendar: calendar), 1)

        appState.toggleHabit(habit, now: now, calendar: calendar)
        XCTAssertTrue(appState.dailyTaskLogs.isEmpty)
        XCTAssertEqual(appState.habitStreak(for: habit, now: now, calendar: calendar), 0)
    }

    func testTodayHabitsRespectsWeekdayMask() throws {
        let anchorWeekday = calendar.component(.weekday, from: now)
        let anchorMask = 1 << (anchorWeekday - 1)
        _ = appState.addDailyTask(title: "今日习惯", kind: .habit, weekdayMask: anchorMask, now: now)
        _ = appState.addDailyTask(title: "每日习惯", kind: .habit, weekdayMask: 0, now: now)

        let scheduled = appState.todayHabits(now: now, calendar: calendar)
        XCTAssertEqual(scheduled.map(\.title).sorted(), ["今日习惯", "每日习惯"])
    }

    func testTodayDailyTaskTotals() throws {
        _ = appState.addDailyTask(title: "待办一", now: now)
        let done = appState.addDailyTask(title: "待办二", now: now)
        appState.toggleTodo(try XCTUnwrap(done), now: now)
        let habit = appState.addDailyTask(title: "习惯", kind: .habit, weekdayMask: 0, now: now)
        appState.completeHabit(try XCTUnwrap(habit), on: now, now: now, calendar: calendar)

        let totals = appState.todayDailyTaskTotals(now: now, calendar: calendar)
        XCTAssertEqual(totals.done, 2)
        XCTAssertEqual(totals.total, 3)
        XCTAssertEqual(appState.todayDailyCompletionCount(now: now, calendar: calendar), 2)
    }

    // MARK: - 生命周期

    func testArchiveHidesFromTodayButKeepsHistory() throws {
        let habit = try XCTUnwrap(appState.addDailyTask(title: "旧习惯", kind: .habit, now: now))
        appState.completeHabit(habit, on: now, now: now, calendar: calendar)
        appState.archiveDailyTask(habit, now: now)

        XCTAssertTrue(appState.todayHabits(now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(appState.dailyTaskLogs.count, 1, "归档保留历史打卡")

        appState.unarchiveDailyTask(habit)
        XCTAssertEqual(appState.todayHabits(now: now, calendar: calendar).count, 1)
    }

    func testDeleteTaskCascadesLogs() throws {
        let habit = try XCTUnwrap(appState.addDailyTask(title: "将删除", kind: .habit, now: now))
        appState.completeHabit(habit, on: now, now: now, calendar: calendar)

        appState.deleteDailyTask(habit)

        XCTAssertTrue(appState.dailyTasks.isEmpty)
        XCTAssertTrue(appState.dailyTaskLogs.isEmpty)
        XCTAssertNil(appState.dailyTaskByID[habit.id])
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<DailyTaskLog>()).count, 0)
    }

    func testReloadRebuildsIndexesConsistently() throws {
        _ = appState.addDailyTask(title: "持久任务", now: now)
        let habit = try XCTUnwrap(appState.addDailyTask(title: "持久习惯", kind: .habit, now: now))
        appState.completeHabit(habit, on: now, now: now, calendar: calendar)

        appState.load()

        XCTAssertEqual(appState.dailyTasks.count, 2)
        XCTAssertEqual(appState.dailyTaskByID.count, 2)
        XCTAssertEqual(appState.dailyTaskLogsByTaskID[habit.id]?.count, 1)
        XCTAssertTrue(appState.isHabitCompletedToday(habit, now: now, calendar: calendar))
    }

    // MARK: - 导入导出

    func testExportImportRoundTripsDailyLessonData() async throws {
        _ = appState.addDailyTask(title: "导出待办", now: now)
        let habit = try XCTUnwrap(appState.addDailyTask(
            title: "导出习惯",
            kind: .habit,
            weekdayMask: 0b0111_1110,
            now: now
        ))
        appState.completeHabit(habit, on: now, now: now, calendar: calendar)
        _ = appState.startFocusSession(minutes: 25, now: now)
        appState.pumpFocusTick(now: now.addingTimeInterval(25 * 60 + 5))

        let data = try appState.exportJSON()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(ExportBundle.self, from: data)
        XCTAssertEqual(bundle.dailyTasks?.count, 2)
        XCTAssertEqual(bundle.dailyTaskLogs?.count, 1)
        XCTAssertEqual(bundle.focusSessions?.count, 1)
        XCTAssertEqual(bundle.focusSessions?.first?.statusRawValue, "completed")

        try await appState.importJSON(data)

        XCTAssertEqual(appState.dailyTasks.count, 2, "日课随配置导入按 id 合并")
        XCTAssertEqual(appState.dailyTaskLogs.count, 1)
        XCTAssertEqual(appState.focusSessions.count, 1)
        XCTAssertEqual(
            appState.dailyTaskLogsByTaskID[habit.id]?.count,
            1,
            "reload 后打卡索引保持一致"
        )
    }

    // MARK: - 知识点关联与评分零污染

    func testKnowledgeNodeLinkResolvesForDisplay() throws {
        let node = KnowledgeNode(name: "Actor 隔离", domain: "Swift")
        container.mainContext.insert(node)
        try container.mainContext.save()
        appState.load()

        let task = appState.addDailyTask(title: "研读 Actor 模型", knowledgeNodeID: node.id, now: now)
        XCTAssertEqual(appState.knowledgeNode(for: try XCTUnwrap(task))?.id, node.id)
    }

    func testDailyLessonAndFocusNeverTouchScoringSystem() throws {
        let node = KnowledgeNode(name: "虚拟内存", domain: "操作系统")
        let mastery = MasteryState(
            knowledgeNodeID: node.id,
            vector: MasteryVector(exposure: 40, understanding: 30, practice: 20, retention: 25, autonomy: 15),
            confidence: 50,
            stabilityDays: 3,
            lastEvidenceAt: nil,
            lifetimeXP: 120
        )
        container.mainContext.insert(node)
        container.mainContext.insert(mastery)
        try container.mainContext.save()
        appState.load()

        let todo = appState.addDailyTask(title: "写页面置换笔记", knowledgeNodeID: node.id, now: now)
        appState.toggleTodo(try XCTUnwrap(todo), now: now)
        let habit = appState.addDailyTask(title: "晨读操作系统", kind: .habit, knowledgeNodeID: node.id, now: now)
        appState.completeHabit(try XCTUnwrap(habit), on: now, now: now, calendar: calendar)
        let session = appState.startFocusSession(minutes: 1, taskID: todo?.id, now: now)
        appState.pumpFocusTick(now: now.addingTimeInterval(120))

        XCTAssertEqual(appState.evidenceRecords.count, 0, "自报完成不得生成学习证据")
        XCTAssertEqual(appState.scoreLedgerEntries.count, 0, "自报完成不得写入评分账本")
        XCTAssertEqual(appState.masteryStates.first?.lifetimeXP, 120, "自报完成不得改变知验 XP")
        XCTAssertEqual(appState.masteryStates.first?.vector.exposure, 40)
        XCTAssertEqual(appState.masteryStates.first?.peakComposite ?? -1, 24.5, accuracy: 0.001)
    }
}
