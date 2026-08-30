import SwiftData
import XCTest
@testable import Ascend

@MainActor
final class FocusSessionTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var calendar: Calendar!
    private var now: Date!

    override func setUpWithError() throws {
        container = PersistenceController.makeContainer(inMemory: true)
        suiteName = "FocusSessionTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        appState = AppState(modelContainer: container, automationDefaults: defaults)
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = gregorian
        now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 20)))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - 会话守卫

    func testOnlyOneActiveSessionAllowed() throws {
        let first = appState.startFocusSession(minutes: 25, now: now)
        XCTAssertNotNil(first)
        XCTAssertEqual(appState.activeFocusSession?.id, first?.id)

        let second = appState.startFocusSession(minutes: 10, now: now.addingTimeInterval(60))
        XCTAssertNil(second, "活跃会话存在时不得重复开始")
        XCTAssertEqual(appState.focusSessions.count, 1)
    }

    func testSessionPersistsWithTaskBinding() throws {
        let taskID = UUID()
        let session = try XCTUnwrap(appState.startFocusSession(minutes: 45, taskID: taskID, now: now))
        XCTAssertEqual(session.phase, .focus)
        XCTAssertEqual(session.plannedSeconds, 45 * 60)
        XCTAssertEqual(session.taskID, taskID)

        let fetched = try container.mainContext.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(fetched.count, 1)
    }

    // MARK: - 剩余时间与暂停

    func testRemainingSecondsFreezesWhilePaused() throws {
        _ = appState.startFocusSession(minutes: 25, now: now)

        var tick = now.addingTimeInterval(10 * 60)
        appState.pumpFocusTick(now: tick)
        XCTAssertEqual(appState.focusRemainingSeconds, 15 * 60)

        appState.pauseFocusSession(now: tick)
        tick = tick.addingTimeInterval(5 * 60)
        appState.pumpFocusTick(now: tick)
        XCTAssertEqual(
            appState.focusRemainingSeconds,
            15 * 60,
            "暂停期间剩余时间必须冻结"
        )
        XCTAssertTrue(appState.isFocusSessionPaused)

        appState.resumeFocusSession(now: tick)
        XCTAssertFalse(appState.isFocusSessionPaused)
        tick = tick.addingTimeInterval(60)
        appState.pumpFocusTick(now: tick)
        XCTAssertEqual(appState.focusRemainingSeconds, 14 * 60)
    }

    // MARK: - 结算

    func testElapsedSessionSettlesExactlyOnce() throws {
        let session = try XCTUnwrap(appState.startFocusSession(minutes: 25, now: now))
        let elapsed = now.addingTimeInterval(25 * 60 + 5)

        appState.pumpFocusTick(now: elapsed)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.endedAt, elapsed)
        XCTAssertNil(appState.activeFocusSession)

        appState.pumpFocusTick(now: elapsed.addingTimeInterval(60))
        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<FocusSession>()).count,
            1,
            "到点结算必须幂等，不得产生新会话"
        )
    }

    func testInterruptedSessionExcludedFromStats() throws {
        _ = appState.startFocusSession(minutes: 25, now: now)
        appState.interruptFocusSession(now: now.addingTimeInterval(5 * 60))

        let session = try XCTUnwrap(appState.focusSessions.first)
        XCTAssertEqual(session.status, .interrupted)
        XCTAssertEqual(appState.todayCompletedFocusCount(now: now, calendar: calendar), 0)
        XCTAssertEqual(appState.todayFocusMinutes(now: now, calendar: calendar), 0)
        XCTAssertNil(appState.activeFocusSession)
    }

    func testTodayFocusStatsCountOnlyCompletedFocusToday() throws {
        let first = try XCTUnwrap(appState.startFocusSession(minutes: 25, now: now))
        appState.pumpFocusTick(now: now.addingTimeInterval(25 * 60))
        XCTAssertEqual(first.status, .completed)

        _ = appState.startRestSession(now: now.addingTimeInterval(25 * 60 + 10), calendar: calendar)
        appState.pumpFocusTick(now: now.addingTimeInterval(25 * 60 + 10 + 5 * 60))

        XCTAssertEqual(appState.todayCompletedFocusCount(now: now, calendar: calendar), 1, "休息轮不计入炷数")
        XCTAssertEqual(appState.todayFocusMinutes(now: now, calendar: calendar), 25)
    }

    func testTaskFocusCountToday() throws {
        let taskID = UUID()
        _ = appState.startFocusSession(minutes: 1, taskID: taskID, now: now)
        appState.pumpFocusTick(now: now.addingTimeInterval(120))

        XCTAssertEqual(appState.todayFocusCount(for: taskID, now: now, calendar: calendar), 1)
        XCTAssertEqual(appState.todayFocusCount(for: UUID(), now: now, calendar: calendar), 0)
    }

    // MARK: - 休息时长推导

    func testRestIsLongAfterConfiguredRounds() throws {
        var preferences = FocusPreferences.current(defaults: defaults)
        preferences.focusMinutes = 25
        preferences.breakMinutes = 5
        preferences.longBreakMinutes = 15
        preferences.sessionsPerLongBreak = 4
        preferences.save(to: defaults)

        func restSeconds(after count: Int) -> Int {
            FocusEngine.restSeconds(afterCompletedFocusCount: count, preferences: FocusPreferences.current(defaults: defaults)) / 60
        }
        XCTAssertEqual(restSeconds(after: 1), 5)
        XCTAssertEqual(restSeconds(after: 3), 5)
        XCTAssertEqual(restSeconds(after: 4), 15, "连续 4 轮后应进入长休息")
        XCTAssertEqual(restSeconds(after: 8), 15)

        for index in 0..<4 {
            _ = appState.startFocusSession(minutes: 1, now: now)
            appState.activeFocusSession?.statusRawValue = FocusSessionStatus.completed.rawValue
            appState.activeFocusSession?.endedAt = now.addingTimeInterval(TimeInterval(60 * (index + 1)))
            appState.activeFocusSession?.startedAt = now.addingTimeInterval(TimeInterval(60 * index))
            try container.mainContext.save()
            appState.load()
        }
        _ = appState.startRestSession(now: now, calendar: calendar)
        XCTAssertEqual(
            appState.activeFocusSession?.plannedSeconds,
            15 * 60,
            "今日已完成 4 轮后 startRestSession 应给出长休息"
        )
    }

    // MARK: - 重启恢复

    func testRecoverySettlesExpiredSessionAtPlannedEnd() throws {
        let startedAt = now.addingTimeInterval(-2 * 3_600)
        let stale = FocusSession(phase: .focus, plannedSeconds: 25 * 60, startedAt: startedAt)
        container.mainContext.insert(stale)
        try container.mainContext.save()

        let freshState = AppState(modelContainer: container, automationDefaults: defaults)

        let recovered = try XCTUnwrap(freshState.focusSessions.first)
        XCTAssertEqual(recovered.status, .completed, "过期的活跃会话重启后应按完成结算")
        XCTAssertEqual(recovered.endedAt, startedAt.addingTimeInterval(25 * 60), "结算时间应为计划结束点，避免统计虚增")
        XCTAssertEqual(freshState.todayCompletedFocusCount(now: now, calendar: calendar), 1, "当日过期会话应计入今日统计且不重复")
    }

    func testRecoveryResumesUnexpiredSession() throws {
        // 恢复发生在真实启动时刻，锚点必须相对真实时钟。
        let stale = FocusSession(phase: .focus, plannedSeconds: 25 * 60, startedAt: Date.now.addingTimeInterval(-600))
        container.mainContext.insert(stale)
        try container.mainContext.save()

        let freshState = AppState(modelContainer: container, automationDefaults: defaults)

        let recovered = try XCTUnwrap(freshState.activeFocusSession)
        XCTAssertEqual(recovered.id, stale.id)
        let remaining = FocusEngine.remainingSeconds(for: recovered, now: .now)
        XCTAssertGreaterThan(remaining, 25 * 60 - 610)
        XCTAssertLessThanOrEqual(remaining, 25 * 60 - 600, "未到期会话应保留剩余时间继续计时")
    }

    func testRecoveryInterruptsDuplicateActiveSessions() throws {
        let older = FocusSession(phase: .focus, plannedSeconds: 25 * 60, startedAt: Date.now.addingTimeInterval(-60))
        let newest = FocusSession(phase: .focus, plannedSeconds: 25 * 60, startedAt: Date.now)
        container.mainContext.insert(older)
        container.mainContext.insert(newest)
        try container.mainContext.save()

        let freshState = AppState(modelContainer: container, automationDefaults: defaults)

        XCTAssertEqual(freshState.activeFocusSession?.id, newest.id, "只保留最新会话继续计时")
        XCTAssertEqual(older.status, .interrupted)
    }

    // MARK: - 引擎纯计算

    func testRemainingClampedWhenReferenceClockBehindSessionStart() {
        // 心跳时钟可能残留上一轮会话的旧值，早于本轮开始时不得"倒着走"
        let session = FocusSession(phase: .focus, plannedSeconds: 900, startedAt: now)
        XCTAssertEqual(
            FocusEngine.remainingSeconds(for: session, now: now.addingTimeInterval(-3)),
            900
        )
        XCTAssertEqual(
            FocusEngine.remainingSeconds(for: session, now: now.addingTimeInterval(60)),
            840
        )
    }

    func testEffectiveSeconds() {
        let completed = FocusSession(
            phase: .focus,
            plannedSeconds: 1_500,
            startedAt: now,
            endedAt: now.addingTimeInterval(1_500),
            status: .completed
        )
        XCTAssertEqual(FocusEngine.effectiveSeconds(for: completed), 1_500)

        let interrupted = FocusSession(
            phase: .focus,
            plannedSeconds: 1_500,
            startedAt: now,
            endedAt: now.addingTimeInterval(600),
            status: .interrupted
        )
        XCTAssertEqual(FocusEngine.effectiveSeconds(for: interrupted), 600)

        let active = FocusSession(phase: .focus, plannedSeconds: 1_500, startedAt: now)
        XCTAssertEqual(FocusEngine.effectiveSeconds(for: active), 0)
    }

    func testPreferencesRoundTripAndClamp() {
        var preferences = FocusPreferences.current(defaults: defaults)
        preferences.focusMinutes = 999
        preferences.breakMinutes = 0
        preferences.floatsOnTop = false
        preferences.save(to: defaults)

        let reloaded = FocusPreferences.current(defaults: defaults)
        XCTAssertEqual(reloaded.focusMinutes, 180)
        XCTAssertEqual(reloaded.breakMinutes, 1)
        XCTAssertFalse(reloaded.floatsOnTop)
    }
}
