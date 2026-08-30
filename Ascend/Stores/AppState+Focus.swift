import Foundation
import SwiftData
import UserNotifications

// MARK: - 专注模式（焚香计时）
//
// 专注是自报的时间投入：会话结算绝不产生 EvidenceRecord、ScoreLedger 或掌握度变化。
// 计时状态持久化于 FocusSession，关窗与进程重启均不丢；重启时过期会话按计划时长结算。

extension AppState {
    var focusPreferences: FocusPreferences {
        FocusPreferences.current(defaults: automationDefaults)
    }

    /// 就地更新专注偏好并持久化。
    func updateFocusPreferences(_ mutate: (inout FocusPreferences) -> Void) {
        var preferences = focusPreferences
        mutate(&preferences)
        preferences.save(to: automationDefaults)
    }

    var activeFocusSession: FocusSession? {
        focusSessions.first { $0.status == .active }
    }

    // MARK: 启动会话

    /// 开始一段专注（一炷香）。同一时间只允许一段活跃会话。
    @discardableResult
    func startFocusSession(minutes: Int? = nil, taskID: UUID? = nil, now: Date = .now) -> FocusSession? {
        guard activeFocusSession == nil else {
            statusMessage = "已有一段专注在进行"
            return nil
        }
        let plannedMinutes = (minutes ?? focusPreferences.focusMinutes).clamped(to: FocusPreferences.focusMinutesRange)
        return insertSession(
            FocusSession(
                taskID: taskID,
                phase: .focus,
                plannedSeconds: plannedMinutes * 60,
                startedAt: now
            )
        )
    }

    /// 专注结束后进入休息；连续完成 `sessionsPerLongBreak` 轮后为长休息。
    @discardableResult
    func startRestSession(now: Date = .now, calendar: Calendar = .current) -> FocusSession? {
        guard activeFocusSession == nil else {
            statusMessage = "已有一段专注在进行"
            return nil
        }
        let completedToday = todayCompletedFocusCount(now: now, calendar: calendar)
        let seconds = FocusEngine.restSeconds(
            afterCompletedFocusCount: completedToday,
            preferences: focusPreferences
        )
        return insertSession(FocusSession(phase: .rest, plannedSeconds: seconds, startedAt: now))
    }

    private func insertSession(_ session: FocusSession) -> FocusSession? {
        modelContext.insert(session)
        do {
            try modelContext.save()
        } catch {
            statusMessage = "专注会话保存失败：\(error.localizedDescription)"
            return nil
        }
        focusSessions.insert(session, at: 0)
        startFocusTickerIfNeeded()
        ensureFocusNotificationAuthorization()
        return session
    }

    // MARK: 暂停与放弃

    func pauseFocusSession(now: Date = .now) {
        guard let session = activeFocusSession, session.pausedAt == nil else { return }
        session.pausedAt = now
        try? modelContext.save()
        focusTick = now
    }

    func resumeFocusSession(now: Date = .now) {
        guard let session = activeFocusSession, let pausedAt = session.pausedAt else { return }
        session.pausedSeconds += max(0, Int(now.timeIntervalSince(pausedAt)))
        session.pausedAt = nil
        try? modelContext.save()
        focusTick = now
    }

    var isFocusSessionPaused: Bool {
        activeFocusSession?.pausedAt != nil
    }

    /// 放弃当前会话：记录为 interrupted，不参与今日专注统计。
    func interruptFocusSession(now: Date = .now) {
        guard let session = activeFocusSession else { return }
        session.pausedAt = nil
        session.endedAt = now
        session.statusRawValue = FocusSessionStatus.interrupted.rawValue
        do {
            try modelContext.save()
        } catch {
            AppLogger.app.error("Failed to save interrupted focus session: \(error.localizedDescription, privacy: .public)")
        }
        stopFocusTicker()
        refreshDerivedState()
        touchDailyLessonObservation()
    }

    // MARK: 心跳与结算

    /// 每秒心跳：仅刷新 focusTick 驱动视图；到点时结算恰好一次。
    func pumpFocusTick(now: Date = .now) {
        focusTick = now
        guard let session = activeFocusSession else {
            stopFocusTicker()
            return
        }
        if FocusEngine.isElapsed(session, now: now) {
            settleFocusSession(session, now: now)
        }
    }

    /// 将活跃会话标记为 completed；重复调用幂等。
    func settleFocusSession(_ session: FocusSession, now: Date = .now) {
        guard session.status == .active else { return }
        session.pausedAt = nil
        session.endedAt = now
        session.statusRawValue = FocusSessionStatus.completed.rawValue
        do {
            try modelContext.save()
        } catch {
            AppLogger.app.error("Failed to save settled focus session: \(error.localizedDescription, privacy: .public)")
        }
        stopFocusTicker()
        refreshDerivedState()
        touchDailyLessonObservation()
        switch session.phase {
        case .focus:
            if !AppRuntime.isRunningTests {
                FocusEngine.playCompletionChime()
            }
            statusMessage = "一炷香已尽，起身舒展片刻"
            deliverFocusPhaseEndNotification(
                title: "知境录 · 一炷香已尽",
                body: session.taskID.flatMap { dailyTaskByID[$0]?.title }.map { "「\($0)」的专注完成了" }
                    ?? "这一轮专注完成了，休息片刻再继续"
            )
        case .rest:
            statusMessage = "休息结束，回到书案继续"
            deliverFocusPhaseEndNotification(title: "知境录 · 休息结束", body: "回到书案，开始下一炷香吧")
        }
    }

    /// 专注结束的即时提醒：仅在系统通知已授权时投递，未授权则只靠铃音与界面提示。
    /// 属用户发起的瞬态计时提醒，不进入战报分类开关体系，也不写 AutomationReceipt。
    private func deliverFocusPhaseEndNotification(title: String, body: String) {
        guard !AppRuntime.isRunningTests else { return }
        let scheduler = digestScheduler
        Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot = await scheduler.permissionSnapshot()
            guard snapshot.isAuthorizedOrProvisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "ascend.focus-phase-end",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// 结束通知是专注的唯一提醒通道：未决定权限时在首轮开始前请求一次。
    private func ensureFocusNotificationAuthorization() {
        guard !AppRuntime.isRunningTests else { return }
        let scheduler = digestScheduler
        Task { @MainActor in
            let snapshot = await scheduler.permissionSnapshot()
            guard snapshot.authorizationStatus == .notDetermined else { return }
            try? await scheduler.requestAuthorization()
        }
    }

    func startFocusTickerIfNeeded() {
        guard focusTickerTask == nil, activeFocusSession != nil else { return }
        // 测试中时间由注入参数控制，真实心跳会与固定 now 互相干扰。
        guard !AppRuntime.isRunningTests else { return }
        focusTickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.pumpFocusTick()
            }
        }
    }

    func stopFocusTicker() {
        focusTickerTask?.cancel()
        focusTickerTask = nil
    }

    /// 重启/加载恢复：多余的活跃会话记为中断；已到点的按计划时长精确结算，未到点的恢复倒计时。
    func recoverFocusSessionsIfNeeded(now: Date = .now) {
        let activeSessions = focusSessions.filter { $0.status == .active }
        guard !activeSessions.isEmpty else { return }
        for stale in activeSessions.dropFirst() {
            stale.statusRawValue = FocusSessionStatus.interrupted.rawValue
            stale.endedAt = now
        }
        let session = activeSessions[0]
        if FocusEngine.isElapsed(session, now: now) {
            let plannedEnd = session.startedAt.addingTimeInterval(
                TimeInterval(session.plannedSeconds + session.pausedSeconds)
            )
            settleFocusSession(session, now: plannedEnd)
        } else {
            startFocusTickerIfNeeded()
        }
    }

    // MARK: 统计

    /// 今日已完成专注轮数（一炷香数）。
    func todayCompletedFocusCount(now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        return focusSessions.count { session in
            guard session.phase == .focus, session.status == .completed else { return false }
            guard let endedAt = session.endedAt else { return false }
            return calendar.isDate(endedAt, inSameDayAs: today)
        }
    }

    /// 今日累计专注有效分钟数（仅计完整完成的轮次）。
    func todayFocusMinutes(now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        return focusSessions
            .filter { session in
                guard session.phase == .focus, session.status == .completed else { return false }
                guard let endedAt = session.endedAt else { return false }
                return calendar.isDate(endedAt, inSameDayAs: today)
            }
            .reduce(0) { $0 + FocusEngine.effectiveSeconds(for: $1) } / 60
    }

    /// 某任务今日完成的专注轮数。
    func todayFocusCount(for taskID: UUID, now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        return focusSessions.count { session in
            session.phase == .focus
                && session.status == .completed
                && session.taskID == taskID
                && session.endedAt.map { calendar.isDate($0, inSameDayAs: today) } == true
        }
    }

    /// 当前会话剩余秒数；无会话时返回 nil。
    var focusRemainingSeconds: Int? {
        activeFocusSession.map { FocusEngine.remainingSeconds(for: $0, now: focusTick) }
    }
}
