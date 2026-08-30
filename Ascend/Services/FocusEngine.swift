import AppKit
import Foundation

/// 专注计时纯计算：剩余时间（含暂停累计）、到点判定与休息时长推导。
/// 不持有状态、不触碰 SwiftData；会话结算与落库由 AppState+Focus 负责。
enum FocusEngine {
    /// 剩余秒数 = 计划时长 − 已流逝（暂停期间冻结）；到点后恒为 0。
    /// 参考时钟钳制到不早于开始时刻：心跳可能是上一轮会话的旧值，直接相减会"倒着走"。
    static func remainingSeconds(for session: FocusSession, now: Date = .now) -> Int {
        let reference = max(session.pausedAt ?? now, session.startedAt)
        let elapsed = reference.timeIntervalSince(session.startedAt) - TimeInterval(session.pausedSeconds)
        return max(0, session.plannedSeconds - Int(elapsed.rounded(.up)))
    }

    /// 会话是否已自然到点（仅未结算且未暂停的会话可能到点）。
    static func isElapsed(_ session: FocusSession, now: Date = .now) -> Bool {
        session.status == .active
            && session.pausedAt == nil
            && remainingSeconds(for: session, now: now) <= 0
    }

    /// 实际有效专注秒数：completed 会话计完整有效时长，interrupted 计中断前时长，active 计 0。
    static func effectiveSeconds(for session: FocusSession) -> Int {
        guard let endedAt = session.endedAt else { return 0 }
        let elapsed = endedAt.timeIntervalSince(session.startedAt) - TimeInterval(session.pausedSeconds)
        return max(0, Int(elapsed.rounded()))
    }

    /// 专注结束后应进入的休息时长；连续 `sessionsPerLongBreak` 轮后进入长休息。
    /// `completedFocusCount` 为包含刚结束一轮在内的今日已完成专注轮数。
    static func restSeconds(afterCompletedFocusCount completedFocusCount: Int, preferences: FocusPreferences) -> Int {
        let perLongBreak = max(1, preferences.sessionsPerLongBreak)
        let minutes = completedFocusCount % perLongBreak == 0
            ? preferences.longBreakMinutes
            : preferences.breakMinutes
        return max(1, minutes) * 60
    }

    /// 会话结束提示音；音效缺失时静默降级。
    static func playCompletionChime() {
        NSSound(named: "Glass")?.play()
    }
}
