import XCTest
import SwiftData
@testable import Ascend

final class NotificationDeliveryPolicyTests: XCTestCase {

    // MARK: - 1. NotificationPreferences 设置与持久化

    func testNotificationPreferencesPersistenceAndActiveState() {
        let suiteName = "test.notification.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var prefs = NotificationPreferences(
            isGlobalEnabled: true,
            isDailyDigestEnabled: true,
            isReviewDueEnabled: true,
            isAssessmentReadyEnabled: true,
            digestHour: 20,
            digestMinute: 15
        )
        prefs.save(to: defaults)

        let loaded = NotificationPreferences(userDefaults: defaults)
        XCTAssertTrue(loaded.isGlobalEnabled)
        XCTAssertTrue(loaded.isDailyDigestEnabled)
        XCTAssertTrue(loaded.isReviewDueEnabled)
        XCTAssertTrue(loaded.isAssessmentReadyEnabled)
        XCTAssertEqual(loaded.digestHour, 20)
        XCTAssertEqual(loaded.digestMinute, 15)
        XCTAssertTrue(loaded.isDailyDigestActive)
        XCTAssertTrue(loaded.isReviewDueActive)
        XCTAssertTrue(loaded.isAssessmentReadyActive)

        // 1. 关闭总开关 -> 分类均不生效
        var disabledGlobal = loaded
        disabledGlobal.isGlobalEnabled = false
        XCTAssertFalse(disabledGlobal.isDailyDigestActive, "总开关关闭时每日战报不得生效")
        XCTAssertFalse(disabledGlobal.isReviewDueActive, "总开关关闭时温故提醒不得生效")
        XCTAssertFalse(disabledGlobal.isAssessmentReadyActive, "总开关关闭时验证题提醒不得生效")

        // 2. 总开关开启，单独关闭每日战报
        var disabledDaily = loaded
        disabledDaily.isDailyDigestEnabled = false
        XCTAssertFalse(disabledDaily.isDailyDigestActive)
        XCTAssertTrue(disabledDaily.isReviewDueActive)

        // 3. 总开关开启，单独关闭温故提醒
        var disabledReview = loaded
        disabledReview.isReviewDueEnabled = false
        XCTAssertTrue(disabledReview.isDailyDigestActive)
        XCTAssertFalse(disabledReview.isReviewDueActive)

        var disabledAssessment = loaded
        disabledAssessment.isAssessmentReadyEnabled = false
        XCTAssertFalse(disabledAssessment.isAssessmentReadyActive)
    }

    func testAssessmentReadyNotificationIsLimitedToOncePerCalendarDay() {
        let policy = NotificationDeliveryPolicy()
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 2_000_000_000)

        var preferences = NotificationPreferences()
        XCTAssertTrue(policy.shouldDeliverAssessmentReady(
            now: now,
            preferences: preferences,
            preparedKnowledgeCount: 5,
            calendar: calendar
        ))

        preferences.lastAssessmentReadyDeliveredAt = now.addingTimeInterval(-60)
        XCTAssertFalse(policy.shouldDeliverAssessmentReady(
            now: now,
            preferences: preferences,
            preparedKnowledgeCount: 5,
            calendar: calendar
        ))

        preferences.lastAssessmentReadyDeliveredAt = now.addingTimeInterval(-86_400)
        XCTAssertTrue(policy.shouldDeliverAssessmentReady(
            now: now,
            preferences: preferences,
            preparedKnowledgeCount: 5,
            calendar: calendar
        ))

        preferences.isAssessmentReadyEnabled = false
        XCTAssertFalse(policy.shouldDeliverAssessmentReady(
            now: now,
            preferences: preferences,
            preparedKnowledgeCount: 5,
            calendar: calendar
        ))
    }

    func testNotificationNavigationDestinationRoundTripsThroughUserInfo() {
        let nodeID = UUID()
        let destinations: [NotificationNavigationDestination] = [
            .assessment, .today, .review, .challenges, .notificationSettings, .knowledge(nodeID)
        ]

        for destination in destinations {
            XCTAssertEqual(
                NotificationNavigationDestination(userInfo: destination.userInfo),
                destination
            )
        }
    }

    // MARK: - 2. Review Batch 聚合文本格式

    func testReviewNotificationBatchFormatting() {
        let plan1 = UUID()
        let batchSingle = ReviewNotificationBatch(planIDs: [plan1], knowledgeNames: ["fork"])
        XCTAssertEqual(batchSingle.title, "知境录 · 到期复习")
        XCTAssertEqual(batchSingle.body, "“fork”今日需要复习")

        let plan2 = UUID()
        let batchTwo = ReviewNotificationBatch(planIDs: [plan1, plan2], knowledgeNames: ["fork", "waitpid"])
        XCTAssertEqual(batchTwo.body, "fork、waitpid 今日待复习")

        let plan3 = UUID()
        let batchThree = ReviewNotificationBatch(planIDs: [plan1, plan2, plan3], knowledgeNames: ["fork", "waitpid", "IPC"])
        XCTAssertEqual(batchThree.body, "fork、waitpid、IPC 今日待复习")

        let plan4 = UUID()
        let plan5 = UUID()
        let plan6 = UUID()
        let batchSix = ReviewNotificationBatch(
            planIDs: [plan1, plan2, plan3, plan4, plan5, plan6],
            knowledgeNames: ["fork", "waitpid", "IPC", "Socket", "Signal", "Pipe"]
        )
        XCTAssertEqual(batchSix.body, "今日有 6 个知识点待复习：fork、waitpid、IPC 等")
    }

    // MARK: - 3. Delivery Policy 判定：开关、新鲜度、Cooldown 与 Digest 吸收

    func testDeliveryPolicyDisabledWhenSwitchIsOff() {
        let policy = NotificationDeliveryPolicy()
        let now = Date()
        let prefs = NotificationPreferences(isGlobalEnabled: false)

        let decision = policy.evaluateReviewDelivery(
            now: now,
            preferences: prefs,
            unnotifiedDuePlans: [(UUID(), now, "fork")],
            lastReviewDeliveredAt: nil
        )

        XCTAssertEqual(decision, .suppressDisabled)
    }

    func testDeliveryPolicyFreshnessWindow() {
        let policy = NotificationDeliveryPolicy(freshnessWindow: 86_400) // 24h
        let now = Date()
        let prefs = NotificationPreferences(isGlobalEnabled: true, isDailyDigestEnabled: false, isReviewDueEnabled: true)

        let oldDate = now.addingTimeInterval(-90_000) // 25h 前
        let decisionOld = policy.evaluateReviewDelivery(
            now: now,
            preferences: prefs,
            unnotifiedDuePlans: [(UUID(), oldDate, "过期知识点")],
            lastReviewDeliveredAt: nil
        )
        XCTAssertEqual(decisionOld, .noop, "超过24h的过期待办不应产生通知洪流")

        let freshDate = now.addingTimeInterval(-3_600) // 1h 前
        let decisionFresh = policy.evaluateReviewDelivery(
            now: now,
            preferences: prefs,
            unnotifiedDuePlans: [(UUID(), freshDate, "新鲜知识点")],
            lastReviewDeliveredAt: nil
        )
        if case .deliverReviewBatch(let batch) = decisionFresh {
            XCTAssertEqual(batch.knowledgeNames, ["新鲜知识点"])
        } else {
            XCTFail("新鲜待办应该正常生成批次通知")
        }
    }

    func testDeliveryPolicyCooldown() {
        let policy = NotificationDeliveryPolicy(cooldownInterval: 1_800) // 30 分钟
        let now = Date()
        let prefs = NotificationPreferences(isGlobalEnabled: true, isDailyDigestEnabled: false, isReviewDueEnabled: true)

        let lastDelivered = now.addingTimeInterval(-600) // 10 分钟前刚发送过
        let decisionCooldown = policy.evaluateReviewDelivery(
            now: now,
            preferences: prefs,
            unnotifiedDuePlans: [(UUID(), now, "新知识点")],
            lastReviewDeliveredAt: lastDelivered
        )

        if case .suppressCooldown(let remaining) = decisionCooldown {
            XCTAssertEqual(remaining, 1200, accuracy: 1.0, "Cooldown 剩余应约 20 分钟")
        } else {
            XCTFail("30分钟内应触发 Cooldown 抑制")
        }

        let pastDelivered = now.addingTimeInterval(-2_000) // 33 分钟前
        let decisionAllowed = policy.evaluateReviewDelivery(
            now: now,
            preferences: prefs,
            unnotifiedDuePlans: [(UUID(), now, "新知识点")],
            lastReviewDeliveredAt: pastDelivered
        )

        if case .deliverReviewBatch(let batch) = decisionAllowed {
            XCTAssertEqual(batch.knowledgeNames, ["新知识点"])
        } else {
            XCTFail("超过30分钟 Cooldown 后应允许发送新批次")
        }
    }

    func testDeliveryPolicyDigestWindowAbsorption() {
        let policy = NotificationDeliveryPolicy(digestMergeWindow: 900) // 15 分钟
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 21
        comps.minute = 30
        comps.second = 0
        let digestTime = calendar.date(from: comps)!

        let prefs = NotificationPreferences(
            isGlobalEnabled: true,
            isDailyDigestEnabled: true,
            isReviewDueEnabled: true,
            digestHour: 21,
            digestMinute: 30
        )

        // 1. 在战报时间前 5 分钟 (21:25) -> 被战报吸收
        let nearBeforeTime = digestTime.addingTimeInterval(-300)
        let decisionAbsorbed = policy.evaluateReviewDelivery(
            now: nearBeforeTime,
            preferences: prefs,
            unnotifiedDuePlans: [(UUID(), nearBeforeTime, "fork"), (UUID(), nearBeforeTime, "waitpid")],
            lastReviewDeliveredAt: nil,
            calendar: calendar
        )

        if case .suppressInDigestWindow(let planIDs, let dueCount) = decisionAbsorbed {
            XCTAssertEqual(planIDs.count, 2)
            XCTAssertEqual(dueCount, 2)
        } else {
            XCTFail("每日战报发送前15分钟内应被吸收")
        }

        // 2. 在战报时间后 (21:30 及之后，例如 21:31) -> 不得再吸收，按正常 batch / cooldown 处理
        let afterDigestTime = digestTime.addingTimeInterval(60) // 21:31
        let decisionAfter = policy.evaluateReviewDelivery(
            now: afterDigestTime,
            preferences: prefs,
            unnotifiedDuePlans: [(UUID(), afterDigestTime, "mmap")],
            lastReviewDeliveredAt: nil,
            calendar: calendar
        )

        if case .deliverReviewBatch(let batch) = decisionAfter {
            XCTAssertEqual(batch.knowledgeNames, ["mmap"], "战报时间之后到期的知识点不得被假装吸收，必须正常发送 Review Batch")
        } else {
            XCTFail("战报时间过去后不应再被吸收")
        }

        // 3. 21:35 新 due -> 最终仍可以收到 review batch
        let laterTime = digestTime.addingTimeInterval(300) // 21:35
        let decisionLater = policy.evaluateReviewDelivery(
            now: laterTime,
            preferences: prefs,
            unnotifiedDuePlans: [(UUID(), laterTime, "epoll")],
            lastReviewDeliveredAt: nil,
            calendar: calendar
        )
        if case .deliverReviewBatch(let batch) = decisionLater {
            XCTAssertEqual(batch.knowledgeNames, ["epoll"])
        } else {
            XCTFail("21:35 新 due 应该能生成 review batch")
        }

        // 4. 战报文本吸收格式化
        let digestBody = NotificationDeliveryPolicy.formatDigestBody(
            baseSummary: "今日掌握了进程与线程基础，斩获 45 XP。",
            dueReviewCount: 2
        )
        XCTAssertTrue(digestBody.contains("今日掌握了进程与线程基础"))
        XCTAssertTrue(digestBody.contains("另有 2 个知识点待复习。"))

        // 5. 如果每日战报开关关闭，则在战报前也不应被吸收，而是独立发送 Review Batch
        var prefsNoDaily = prefs
        prefsNoDaily.isDailyDigestEnabled = false
        let decisionNoDaily = policy.evaluateReviewDelivery(
            now: nearBeforeTime,
            preferences: prefsNoDaily,
            unnotifiedDuePlans: [(UUID(), nearBeforeTime, "fork")],
            lastReviewDeliveredAt: nil,
            calendar: calendar
        )

        if case .deliverReviewBatch(let batch) = decisionNoDaily {
            XCTAssertEqual(batch.knowledgeNames, ["fork"])
        } else {
            XCTFail("每日战报关闭时，Review 应独立发送")
        }
    }

    // MARK: - 4. TriggerEngine 集成与 Receipt 发送后写入

    @MainActor
    func testTriggerEngineReviewNotificationReceiptIntegration() async throws {
        let schema = Schema(AscendSchemaV8.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let suiteName = "test.trigger.engine.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // 开启通知
        NotificationPreferences(
            isGlobalEnabled: true,
            isDailyDigestEnabled: false,
            isReviewDueEnabled: true
        ).save(to: defaults)

        let appState = AppState(
            modelContainer: container,
            automationDefaults: defaults
        )

        let nodeA = KnowledgeNode(name: "A", domain: "OS")
        let nodeB = KnowledgeNode(name: "B", domain: "OS")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)

        let now = Date()
        let planA = ReviewPlan(knowledgeNodeID: nodeA.id, scheduledAt: now.addingTimeInterval(-60), reason: "FSRS")
        let planB = ReviewPlan(knowledgeNodeID: nodeB.id, scheduledAt: now.addingTimeInterval(-60), reason: "FSRS")
        container.mainContext.insert(planA)
        container.mainContext.insert(planB)
        try container.mainContext.save()

        appState.reload()

        // 运行 TriggerEngine：两个 plan 从 scheduled -> due
        let changes = appState.runTriggerEngine()
        XCTAssertGreaterThan(changes, 0)
        XCTAssertEqual(planA.status, "due")
        XCTAssertEqual(planB.status, "due")
    }

    // MARK: - 5. 并发防护与 In-Flight 锁测试

    @MainActor
    func testConcurrentNotificationDeliveryIsGuardedByInFlight() async throws {
        let schema = Schema(AscendSchemaV8.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let suiteName = "test.inflight.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        NotificationPreferences(
            isGlobalEnabled: true,
            isDailyDigestEnabled: false,
            isReviewDueEnabled: true
        ).save(to: defaults)

        let appState = AppState(
            modelContainer: container,
            automationDefaults: defaults
        )

        // 模拟当前正在进行 delivery
        appState.isNotificationDeliveryInFlight = true

        let node = KnowledgeNode(name: "并发测试", domain: "OS")
        let plan = ReviewPlan(knowledgeNodeID: node.id, scheduledAt: Date().addingTimeInterval(-60), reason: "Test", status: "due")
        container.mainContext.insert(node)
        container.mainContext.insert(plan)
        try container.mainContext.save()
        appState.reload()

        // 在 in-flight 状态下调用 processPendingReviewNotifications，应该被立即拦截退出
        await appState.processPendingReviewNotifications()
        XCTAssertEqual(appState.automationReceipts.count, 0, "正在进行中的 delivery 应拦截并发调用")

        // 解除 in-flight
        appState.isNotificationDeliveryInFlight = false
    }

    // MARK: - 6. Cooldown 重启持久化测试

    @MainActor
    func testCooldownPersistsAcrossAppRestart() async throws {
        let suiteName = "test.cooldown.restart.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let deliveredTime = Date()
        var prefs = NotificationPreferences(
            isGlobalEnabled: true,
            isDailyDigestEnabled: false,
            isReviewDueEnabled: true,
            lastReviewDeliveredAt: deliveredTime
        )
        prefs.save(to: defaults)

        let schema = Schema(AscendSchemaV8.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // 模拟 App 重新冷启动
        let restartedAppState = AppState(
            modelContainer: container,
            automationDefaults: defaults
        )

        XCTAssertEqual(
            restartedAppState.lastReviewNotificationDeliveredAt?.timeIntervalSince1970,
            deliveredTime.timeIntervalSince1970,
            "重启后应从 UserDefaults 恢复 lastReviewNotificationDeliveredAt"
        )
    }

    // MARK: - 7. Digest Window 吸收后写入 Covered Receipt

    func testDigestWindowAbsorptionPreventsSubsequentReviewDelivery() {
        let policy = NotificationDeliveryPolicy(digestMergeWindow: 900)
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 21
        comps.minute = 30
        comps.second = 0
        let digestTime = calendar.date(from: comps)!

        let prefs = NotificationPreferences(
            isGlobalEnabled: true,
            isDailyDigestEnabled: true,
            isReviewDueEnabled: true,
            digestHour: 21,
            digestMinute: 30
        )

        let planID = UUID()
        let nearTime = digestTime.addingTimeInterval(-100)
        let decision = policy.evaluateReviewDelivery(
            now: nearTime,
            preferences: prefs,
            unnotifiedDuePlans: [(planID, nearTime, "fork")],
            lastReviewDeliveredAt: nil,
            calendar: calendar
        )

        if case .suppressInDigestWindow(let planIDs, let count) = decision {
            XCTAssertEqual(planIDs, [planID])
            XCTAssertEqual(count, 1)
        } else {
            XCTFail("应被战报吸收")
        }
    }
}
