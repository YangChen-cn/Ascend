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

    func removePendingDailyDigest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["ascend.daily-digest"])
    }

    func purgeLegacyNotificationRequests() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let legacyIDs = requests.compactMap { request -> String? in
                let id = request.identifier
                if id.starts(with: "ascend.review-plan.") || id.starts(with: "ascend.review-due.") || (id.starts(with: "ascend.digest.") && id != "ascend.daily-digest") {
                    return id
                }
                return nil
            }
            if !legacyIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: legacyIDs)
            }
        }
        center.getDeliveredNotifications { notifications in
            let legacyIDs = notifications.compactMap { notification -> String? in
                let id = notification.request.identifier
                if id.starts(with: "ascend.review-plan.") || id.starts(with: "ascend.review-due.") || (id.starts(with: "ascend.digest.") && id != "ascend.daily-digest") {
                    return id
                }
                return nil
            }
            if !legacyIDs.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: legacyIDs)
            }
        }
    }

    func scheduleDailyDigest(hour: Int, minute: Int, dueReviewCount: Int = 0) async throws {
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
        content.body = NotificationDeliveryPolicy.formatDigestBody(
            baseSummary: "今日修真心得已就绪。点击查看今日 XP 增量、境界跃升与待温故知识点。",
            dueReviewCount: dueReviewCount
        )
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

    func sendDigestReadyNotification(
        summary: String,
        dueReviewCount: Int = 0,
        identifier: String = "ascend.daily-digest"
    ) async throws {
        let settings = await permissionSnapshot()
        guard settings.isAuthorizedOrProvisional else {
            if settings.authorizationStatus == .notDetermined {
                throw SchedulerError.notDetermined
            } else {
                throw SchedulerError.notificationDenied
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "知境录 · 今日研习战报"
        content.body = NotificationDeliveryPolicy.formatDigestBody(
            baseSummary: String(summary.prefix(120)),
            dueReviewCount: dueReviewCount
        )
        content.sound = .default
        do {
            try await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            )
        } catch {
            throw SchedulerError.systemError(error.localizedDescription)
        }
    }

    func sendReviewBatchNotification(
        batch: ReviewNotificationBatch,
        identifier: String = "ascend.review-batch"
    ) async throws {
        let settings = await permissionSnapshot()
        guard settings.isAuthorizedOrProvisional else {
            if settings.authorizationStatus == .notDetermined {
                throw SchedulerError.notDetermined
            } else {
                throw SchedulerError.notificationDenied
            }
        }

        let content = UNMutableNotificationContent()
        content.title = batch.title
        content.body = batch.body
        content.sound = .default

        do {
            try await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            )
        } catch {
            throw SchedulerError.systemError(error.localizedDescription)
        }
    }

    func sendTestNotification() async throws {
        let settings = await permissionSnapshot()
        guard settings.isAuthorizedOrProvisional else {
            if settings.authorizationStatus == .notDetermined {
                throw SchedulerError.notDetermined
            } else {
                throw SchedulerError.notificationDenied
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "知境录 · 测试通知"
        content.body = "这是一条来自知境录的测试通知。系统通知管道工作正常！"
        content.sound = .default

        do {
            try await UNUserNotificationCenter.current().add(
                UNNotificationRequest(
                    identifier: "ascend.test.\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )
            )
        } catch {
            throw SchedulerError.systemError(error.localizedDescription)
        }
    }
}
