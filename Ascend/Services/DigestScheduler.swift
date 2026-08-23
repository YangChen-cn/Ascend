import Foundation
import UserNotifications

actor DigestScheduler {
    enum SchedulerError: LocalizedError {
        case notificationDenied

        var errorDescription: String? { "通知权限未开启，请在系统设置中允许知境录通知" }
    }

    func requestAuthorization() async throws {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        guard granted else { throw SchedulerError.notificationDenied }
    }

    func scheduleDailyDigest(hour: Int, minute: Int) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["ascend.daily-digest"])
        let content = UNMutableNotificationContent()
        content.title = "今日学习总结已准备"
        content.body = "看看今天掌握了什么、哪些知识正在遗忘，以及下一步最值得做什么。"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        try await center.add(
            UNNotificationRequest(identifier: "ascend.daily-digest", content: content, trigger: trigger)
        )
    }

    func sendDigestReadyNotification(summary: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "知境录 · 今日知得"
        content.body = String(summary.prefix(120))
        content.sound = .default
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}
