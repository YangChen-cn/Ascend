import Foundation
import UserNotifications

actor DigestScheduler {
    enum SchedulerError: LocalizedError {
        case notificationDenied
        case systemError(String)

        var errorDescription: String? {
            switch self {
            case .notificationDenied:
                return "系统通知权限未开启，请在 macOS「系统设置 > 通知 > 知境录」中允许通知"
            case .systemError(let detail):
                return "通知配置失败：\(detail)"
            }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorization() async throws {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            guard granted else { throw SchedulerError.notificationDenied }
        } catch let error as SchedulerError {
            throw error
        } catch {
            throw SchedulerError.notificationDenied
        }
    }

    func scheduleDailyDigest(hour: Int, minute: Int) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["ascend.daily-digest"])
        let content = UNMutableNotificationContent()
        content.title = "知境录 · 今日研习战报"
        content.body = "今日修真心得已就绪。点击查看今日 XP 增量、境界跃升与艾宾浩斯待温故知识点。"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        do {
            try await center.add(
                UNNotificationRequest(identifier: "ascend.daily-digest", content: content, trigger: trigger)
            )
        } catch {
            throw SchedulerError.systemError(error.localizedDescription)
        }
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

    func sendReviewDueNotification(planID: UUID, knowledgeName: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "知境录 · 今日温故"
        content.body = "“\(knowledgeName)”今日需要复习。完成对应练习或复习实据后会自动结清。"
        content.sound = .default
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "ascend.review-plan.\(planID.uuidString)",
                content: content,
                trigger: nil
            )
        )
    }
}
