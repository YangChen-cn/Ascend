import Foundation

struct NotificationPreferences: Sendable, Equatable {
    enum Keys {
        static let notificationsEnabled = "digestNotificationsEnabled"
        static let dailyDigestEnabled = "digestDailyNotificationEnabled"
        static let reviewDueEnabled = "reviewDueNotificationEnabled"
        static let assessmentReadyEnabled = "assessmentReadyNotificationEnabled"
        static let hour = "digestHour"
        static let minute = "digestMinute"
        static let lastReviewNotificationDeliveredAt = "lastReviewNotificationDeliveredAt"
        static let lastAssessmentReadyNotificationDeliveredAt = "lastAssessmentReadyNotificationDeliveredAt"
    }

    var isGlobalEnabled: Bool
    var isDailyDigestEnabled: Bool
    var isReviewDueEnabled: Bool
    var isAssessmentReadyEnabled: Bool
    var digestHour: Int
    var digestMinute: Int
    var lastReviewDeliveredAt: Date?
    var lastAssessmentReadyDeliveredAt: Date?

    init(
        isGlobalEnabled: Bool = true,
        isDailyDigestEnabled: Bool = true,
        isReviewDueEnabled: Bool = true,
        isAssessmentReadyEnabled: Bool = true,
        digestHour: Int = AppConstants.defaultDigestHour,
        digestMinute: Int = AppConstants.defaultDigestMinute,
        lastReviewDeliveredAt: Date? = nil,
        lastAssessmentReadyDeliveredAt: Date? = nil
    ) {
        self.isGlobalEnabled = isGlobalEnabled
        self.isDailyDigestEnabled = isDailyDigestEnabled
        self.isReviewDueEnabled = isReviewDueEnabled
        self.isAssessmentReadyEnabled = isAssessmentReadyEnabled
        self.digestHour = digestHour
        self.digestMinute = digestMinute
        self.lastReviewDeliveredAt = lastReviewDeliveredAt
        self.lastAssessmentReadyDeliveredAt = lastAssessmentReadyDeliveredAt
    }

    init(userDefaults: UserDefaults) {
        self.isGlobalEnabled = userDefaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.isDailyDigestEnabled = userDefaults.object(forKey: Keys.dailyDigestEnabled) as? Bool ?? true
        self.isReviewDueEnabled = userDefaults.object(forKey: Keys.reviewDueEnabled) as? Bool ?? true
        self.isAssessmentReadyEnabled = userDefaults.object(forKey: Keys.assessmentReadyEnabled) as? Bool ?? true
        self.digestHour = userDefaults.object(forKey: Keys.hour) as? Int ?? AppConstants.defaultDigestHour
        self.digestMinute = userDefaults.object(forKey: Keys.minute) as? Int ?? AppConstants.defaultDigestMinute
        self.lastReviewDeliveredAt = userDefaults.object(forKey: Keys.lastReviewNotificationDeliveredAt) as? Date
        self.lastAssessmentReadyDeliveredAt = userDefaults.object(forKey: Keys.lastAssessmentReadyNotificationDeliveredAt) as? Date
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(isGlobalEnabled, forKey: Keys.notificationsEnabled)
        userDefaults.set(isDailyDigestEnabled, forKey: Keys.dailyDigestEnabled)
        userDefaults.set(isReviewDueEnabled, forKey: Keys.reviewDueEnabled)
        userDefaults.set(isAssessmentReadyEnabled, forKey: Keys.assessmentReadyEnabled)
        userDefaults.set(digestHour, forKey: Keys.hour)
        userDefaults.set(digestMinute, forKey: Keys.minute)
        if let lastReviewDeliveredAt {
            userDefaults.set(lastReviewDeliveredAt, forKey: Keys.lastReviewNotificationDeliveredAt)
        } else {
            userDefaults.removeObject(forKey: Keys.lastReviewNotificationDeliveredAt)
        }
        if let lastAssessmentReadyDeliveredAt {
            userDefaults.set(lastAssessmentReadyDeliveredAt, forKey: Keys.lastAssessmentReadyNotificationDeliveredAt)
        } else {
            userDefaults.removeObject(forKey: Keys.lastAssessmentReadyNotificationDeliveredAt)
        }
    }

    /// 每日战报是否实际生效（总开关开启且每日战报开启）
    var isDailyDigestActive: Bool {
        isGlobalEnabled && isDailyDigestEnabled
    }

    /// 到期复习提醒是否实际生效（总开关和分类开关均开启）
    var isReviewDueActive: Bool {
        isGlobalEnabled && isReviewDueEnabled
    }

    var isAssessmentReadyActive: Bool {
        isGlobalEnabled && isAssessmentReadyEnabled
    }

    static var `default`: NotificationPreferences {
        NotificationPreferences(userDefaults: .standard)
    }
}
