import Foundation

struct ReviewNotificationBatch: Sendable, Equatable {
    var planIDs: [UUID]
    var knowledgeNames: [String]

    var title: String {
        "知境录 · 到期复习"
    }

    var body: String {
        let count = knowledgeNames.count
        guard count > 0 else { return "今日有知识点待复习" }
        if count == 1 {
            return "“\(knowledgeNames[0])”今日需要复习"
        } else if count <= 3 {
            return "\(knowledgeNames.joined(separator: "、")) 今日待复习"
        } else {
            let prefixNames = knowledgeNames.prefix(3).joined(separator: "、")
            return "今日有 \(count) 个知识点待复习：\(prefixNames) 等"
        }
    }
}

enum NotificationDeliveryDecision: Sendable, Equatable {
    case deliverReviewBatch(ReviewNotificationBatch)
    case suppressInDigestWindow(planIDs: [UUID], dueCount: Int)
    case suppressCooldown(timeRemaining: TimeInterval)
    case suppressDisabled
    case noop
}

struct NotificationDeliveryPolicy: Sendable {
    var cooldownInterval: TimeInterval
    var digestMergeWindow: TimeInterval
    var freshnessWindow: TimeInterval

    init(
        cooldownInterval: TimeInterval = 1_800, // 30 分钟
        digestMergeWindow: TimeInterval = 900,  // ±15 分钟
        freshnessWindow: TimeInterval = 86_400  // 24 小时
    ) {
        self.cooldownInterval = cooldownInterval
        self.digestMergeWindow = digestMergeWindow
        self.freshnessWindow = freshnessWindow
    }

    func evaluateReviewDelivery(
        now: Date = Date(),
        preferences: NotificationPreferences,
        unnotifiedDuePlans: [(planID: UUID, scheduledAt: Date, knowledgeName: String)],
        lastReviewDeliveredAt: Date?,
        calendar: Calendar = .current
    ) -> NotificationDeliveryDecision {
        // 1. 检查总开关与温故开关
        guard preferences.isReviewDueActive else {
            return .suppressDisabled
        }

        // 2. 过滤 freshness 窗口（只提醒 24h 内到期/处于当前周期的计划）
        let freshPlans = unnotifiedDuePlans.filter { plan in
            // 如果 scheduledAt 在当前时间之前不到 24h，或者刚好在当前/未来
            now.timeIntervalSince(plan.scheduledAt) <= freshnessWindow
        }

        guard !freshPlans.isEmpty else {
            return .noop
        }

        // 3. 检查是否在每日战报吸收窗口 (仅限 digestDate 前 15 分钟内，且尚未到达 digestDate) 且每日战报开启
        if preferences.isDailyDigestActive {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = preferences.digestHour
            components.minute = preferences.digestMinute
            components.second = 0
            if let digestDate = calendar.date(from: components) {
                let windowStart = digestDate.addingTimeInterval(-digestMergeWindow)
                if now >= windowStart && now < digestDate {
                    return .suppressInDigestWindow(
                        planIDs: freshPlans.map(\.planID),
                        dueCount: freshPlans.count
                    )
                }
            }
        }

        // 4. 检查 Cooldown (30 分钟)
        if let lastDelivered = lastReviewDeliveredAt {
            let elapsed = now.timeIntervalSince(lastDelivered)
            if elapsed < cooldownInterval {
                return .suppressCooldown(timeRemaining: cooldownInterval - elapsed)
            }
        }

        // 5. 聚合为单个 Batch
        let planIDs = freshPlans.map(\.planID)
        let names = freshPlans.map(\.knowledgeName)
        let batch = ReviewNotificationBatch(planIDs: planIDs, knowledgeNames: names)
        return .deliverReviewBatch(batch)
    }

    func shouldDeliverAssessmentReady(
        now: Date = .now,
        preferences: NotificationPreferences,
        preparedKnowledgeCount: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard preferences.isAssessmentReadyActive, preparedKnowledgeCount > 0 else { return false }
        guard let lastDelivered = preferences.lastAssessmentReadyDeliveredAt else { return true }
        return !calendar.isDate(lastDelivered, inSameDayAs: now)
    }

    /// 每日战报正文吸收温故提示
    static func formatDigestBody(baseSummary: String, dueReviewCount: Int) -> String {
        let trimmed = baseSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if dueReviewCount > 0 {
            if trimmed.isEmpty {
                return "今日研习成果已归档。另有 \(dueReviewCount) 个知识点待复习。"
            } else {
                return "\(trimmed) 另有 \(dueReviewCount) 个知识点待复习。"
            }
        }
        return trimmed.isEmpty ? "今日修真研习心得已就绪。" : trimmed
    }
}
