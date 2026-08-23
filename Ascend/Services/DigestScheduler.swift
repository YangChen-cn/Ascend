import Foundation
import UserNotifications

struct NotificationPermissionSnapshot: Sendable, Equatable {
    var authorizationStatus: UNAuthorizationStatus
    var alertSetting: UNNotificationSetting
    var soundSetting: UNNotificationSetting
    var notificationCenterSetting: UNNotificationSetting

    init(
        authorizationStatus: UNAuthorizationStatus = .notDetermined,
        alertSetting: UNNotificationSetting = .notSupported,
        soundSetting: UNNotificationSetting = .notSupported,
        notificationCenterSetting: UNNotificationSetting = .notSupported
    ) {
        self.authorizationStatus = authorizationStatus
        self.alertSetting = alertSetting
        self.soundSetting = soundSetting
        self.notificationCenterSetting = notificationCenterSetting
    }

    init(settings: UNNotificationSettings) {
        self.authorizationStatus = settings.authorizationStatus
        self.alertSetting = settings.alertSetting
        self.soundSetting = settings.soundSetting
        self.notificationCenterSetting = settings.notificationCenterSetting
    }

    var isAuthorizedOrProvisional: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }
}

actor DigestScheduler {
    enum SchedulerError: LocalizedError, Equatable {
        case notDetermined
        case notificationDenied
        case systemError(String)

        var errorDescription: String? {
            switch self {
            case .notDetermined:
                return "尚未请求系统通知权限，请先开启通知"
            case .notificationDenied:
                return "通知已被系统拒绝，请前往系统设置开启"
            case .systemError(let detail):
                return "通知配置失败：\(detail)"
            }
        }
    }

    func permissionSnapshot() async -> NotificationPermissionSnapshot {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationPermissionSnapshot(settings: settings)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorization() async throws {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { throw SchedulerError.notificationDenied }
        } catch let error as SchedulerError {
            throw error
        } catch {
            throw SchedulerError.notificationDenied
        }
    }

    func scheduleDailyDigest(hour: Int, minute: Int) async throws {
        let settings = await permissionSnapshot()
        guard settings.isAuthorizedOrProvisional else {
            if settings.authorizationStatus == .notDetermined {
                throw SchedulerError.notDetermined
            } else {
                throw SchedulerError.notificationDenied
            }
        }

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
        let settings = await permissionSnapshot()
        guard settings.isAuthorizedOrProvisional else {
            if settings.authorizationStatus == .notDetermined {
                throw SchedulerError.notDetermined
            } else {
                throw SchedulerError.notificationDenied
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "知境录 · 今日知得"
        content.body = String(summary.prefix(120))
        content.sound = .default
        do {
            try await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        } catch {
            throw SchedulerError.systemError(error.localizedDescription)
        }
    }

    func sendReviewDueNotification(planID: UUID, knowledgeName: String) async throws {
        let settings = await permissionSnapshot()
        guard settings.isAuthorizedOrProvisional else { return }

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
