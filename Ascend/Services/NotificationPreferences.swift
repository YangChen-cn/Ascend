import Foundation

struct NotificationPreferences: Sendable, Equatable {
    enum Keys {
        static let notificationsEnabled = "digestNotificationsEnabled"
        static let dailyDigestEnabled = "digestDailyNotificationEnabled"
        static let reviewDueEnabled = "reviewDueNotificationEnabled"
        static let hour = "digestHour"
        static let minute = "digestMinute"
    }

    var isGlobalEnabled: Bool
    var isDailyDigestEnabled: Bool
    var isReviewDueEnabled: Bool
    var digestHour: Int
    var digestMinute: Int

    init(
        isGlobalEnabled: Bool = true,
        isDailyDigestEnabled: Bool = true,
        isReviewDueEnabled: Bool = true,
        digestHour: Int = AppConstants.defaultDigestHour,
        digestMinute: Int = AppConstants.defaultDigestMinute
    ) {
        self.isGlobalEnabled = isGlobalEnabled
        self.isDailyDigestEnabled = isDailyDigestEnabled
        self.isReviewDueEnabled = isReviewDueEnabled
        self.digestHour = digestHour
        self.digestMinute = digestMinute
    }

    init(userDefaults: UserDefaults) {
        self.isGlobalEnabled = userDefaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.isDailyDigestEnabled = userDefaults.object(forKey: Keys.dailyDigestEnabled) as? Bool ?? true
        self.isReviewDueEnabled = userDefaults.object(forKey: Keys.reviewDueEnabled) as? Bool ?? true
        self.digestHour = userDefaults.object(forKey: Keys.hour) as? Int ?? AppConstants.defaultDigestHour
        self.digestMinute = userDefaults.object(forKey: Keys.minute) as? Int ?? AppConstants.defaultDigestMinute
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(isGlobalEnabled, forKey: Keys.notificationsEnabled)
        userDefaults.set(isDailyDigestEnabled, forKey: Keys.dailyDigestEnabled)
        userDefaults.set(isReviewDueEnabled, forKey: Keys.reviewDueEnabled)
        userDefaults.set(digestHour, forKey: Keys.hour)
        userDefaults.set(digestMinute, forKey: Keys.minute)
    }

    /// 每日战报是否实际生效（总开关开启且每日战报开启）
    var isDailyDigestActive: Bool {
        isGlobalEnabled && isDailyDigestEnabled
    }

    /// 温故提醒是否实际生效（总开关开启且温故开启）
    var isReviewDueActive: Bool {
        isGlobalEnabled && isReviewDueEnabled
    }

    static var `default`: NotificationPreferences {
        NotificationPreferences(userDefaults: .standard)
    }
}
