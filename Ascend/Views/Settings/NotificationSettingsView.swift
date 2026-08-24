import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(NotificationPreferences.Keys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(NotificationPreferences.Keys.dailyDigestEnabled) private var dailyDigestEnabled = true
    @AppStorage(NotificationPreferences.Keys.reviewDueEnabled) private var reviewDueEnabled = true
    @AppStorage(NotificationPreferences.Keys.assessmentReadyEnabled) private var assessmentReadyEnabled = true
    @AppStorage(NotificationPreferences.Keys.hour) private var hour = AppConstants.defaultDigestHour
    @AppStorage(NotificationPreferences.Keys.minute) private var minute = AppConstants.defaultDigestMinute

    @State private var permissionSnapshot = NotificationPermissionSnapshot()
    @State private var statusMessage: String?
    @State private var isSendingTest = false

    private let minuteOptions = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    var body: some View {
        Form {
            // MARK: - 1. 总通知开关
            Section {
                Toggle("启用系统通知", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        Task {
                            await appState.updateNotificationSchedule()
                            statusMessage = newValue ? "已开启系统通知" : "已关闭所有自动通知"
                        }
                    }
            } header: {
                Text("通知推送")
            } footer: {
                Text("关闭总开关将停止战报、到期复习与验证题就绪通知，不会影响任何学习记录、FSRS 记忆保持与境界计算。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - 2. 通知类型分类
            Section {
                // 分类 1: 每日研习战报
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("每日研习战报", isOn: $dailyDigestEnabled)
                        .disabled(!notificationsEnabled)
                        .onChange(of: dailyDigestEnabled) { _, newValue in
                            Task {
                                await appState.updateNotificationSchedule()
                                statusMessage = newValue ? "已开启每日研习战报通知" : "已关闭每日研习战报通知"
                            }
                        }
                    Text("每天指定时刻汇总今日学习成果、XP 增量与修真心得")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                if notificationsEnabled && dailyDigestEnabled {
                    LabeledContent("每日推送时刻") {
                        HStack(spacing: 8) {
                            Picker("小时", selection: $hour) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(String(format: "%02d 时", h)).tag(h)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 88)

                            Text(":")
                                .foregroundStyle(.secondary)

                            Picker("分钟", selection: $minute) {
                                ForEach(minuteOptions, id: \.self) { m in
                                    Text(String(format: "%02d 分", m)).tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 88)
                        }
                    }
                    .onChange(of: hour) { _, _ in applySchedule() }
                    .onChange(of: minute) { _, _ in applySchedule() }

                    LabeledContent("快捷预设") {
                        Menu {
                            Button("晚上 21:30 (默认)") { setTime(hour: 21, minute: 30) }
                            Button("深夜 22:00") { setTime(hour: 22, minute: 0) }
                            Button("傍晚 18:30") { setTime(hour: 18, minute: 30) }
                            Button("中午 12:30") { setTime(hour: 12, minute: 30) }
                            Button("上午 09:00") { setTime(hour: 9, minute: 0) }
                        } label: {
                            Label("选择常用时刻…", systemImage: "clock.arrow.circlepath")
                        }
                        .menuStyle(.borderedButton)
                    }

                    LabeledContent("当前预定") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isScheduleActive ? AscendTheme.jade : .secondary)
                                .frame(width: 6, height: 6)
                            Text(isScheduleActive ? "每天 \(String(format: "%02d:%02d", hour, minute)) 定时推送" : "每日战报通知已关闭")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(isScheduleActive ? AscendTheme.jade : .secondary)
                        }
                    }
                } else {
                    LabeledContent("当前预定") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 6, height: 6)
                            Text("每日战报通知已关闭")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 分类 2: FSRS 到期复习提醒
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("到期复习提醒", isOn: $reviewDueEnabled)
                        .disabled(!notificationsEnabled)
                        .onChange(of: reviewDueEnabled) { _, newValue in
                            statusMessage = newValue ? "已开启到期复习提醒" : "已关闭到期复习提醒"
                        }
                    Text("首次验证后安排延迟检索；以后由 FSRS 根据真实答题表现决定复习时间")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("验证题就绪提醒", isOn: $assessmentReadyEnabled)
                        .disabled(!notificationsEnabled)
                        .onChange(of: assessmentReadyEnabled) { _, newValue in
                            statusMessage = newValue ? "已开启验证题就绪提醒" : "已关闭验证题就绪提醒"
                        }
                    Text("题包准备完成时每天最多提醒一次；点击通知直接进入答题界面")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            } header: {
                Text("通知类型")
            } footer: {
                Text("多项到期任务将智能聚合，验证题就绪提醒每天最多一条；每日战报时间附近的复习提醒将自动合并至战报中投递。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - 3. 战报所含研习维度
            Section("战报所含研习维度") {
                LabeledContent("今日知得与经验", value: "汇总当日新增知识点、掌握度与 XP 实据")
                LabeledContent("FSRS 到期复习", value: "根据实际检索表现安排下一次复习")
                LabeledContent("修真境界跃升", value: "各领域修为突破与研习挑战达成")
            }

            // MARK: - 4. 权限与详细诊断
            Section("系统通知权限与诊断") {
                HStack {
                    Text("系统权限授权状态")
                    Spacer()
                    Text(authStatusText)
                        .font(.caption.bold())
                        .foregroundStyle(authStatusColor)
                }

                // 诊断详细矩阵
                LabeledContent("横幅提醒 (Banner)") {
                    Text(settingStatusText(permissionSnapshot.alertSetting))
                        .font(.caption)
                        .foregroundStyle(settingStatusColor(permissionSnapshot.alertSetting))
                }

                LabeledContent("提示声音 (Sound)") {
                    Text(settingStatusText(permissionSnapshot.soundSetting))
                        .font(.caption)
                        .foregroundStyle(settingStatusColor(permissionSnapshot.soundSetting))
                }

                LabeledContent("通知中心 (List)") {
                    Text(settingStatusText(permissionSnapshot.notificationCenterSetting))
                        .font(.caption)
                        .foregroundStyle(settingStatusColor(permissionSnapshot.notificationCenterSetting))
                }

                HStack(spacing: 12) {
                    Button(action: requestPermissionAndApply) {
                        Label("请求开启通知权限", systemImage: "bell.badge")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.jade)

                    Button(action: sendTestNotification) {
                        Label("发送测试通知", systemImage: "paperplane")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSendingTest)

                    Button(action: openSystemNotificationSettings) {
                        Label("打开系统通知设置…", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(statusMessage.contains("失败") || statusMessage.contains("未开启") || statusMessage.contains("未获得") || statusMessage.contains("拒绝") || statusMessage.contains("尚未请求") ? .red : AscendTheme.jade)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await refreshAuthStatus()
        }
    }

    private var isScheduleActive: Bool {
        notificationsEnabled && dailyDigestEnabled && permissionSnapshot.isAuthorizedOrProvisional
    }

    private var authStatusText: String {
        switch permissionSnapshot.authorizationStatus {
        case .authorized:
            return "已完全授权"
        case .provisional:
            return "临时授权 (静默通知)"
        case .denied:
            return "已被系统拒绝"
        case .notDetermined:
            return "尚未请求权限"
        case .ephemeral:
            return "App Clips 临时"
        @unknown default:
            return "未知状态"
        }
    }

    private var authStatusColor: Color {
        switch permissionSnapshot.authorizationStatus {
        case .authorized, .provisional:
            return AscendTheme.jade
        case .denied:
            return .red
        case .notDetermined:
            return AscendTheme.amber
        default:
            return .secondary
        }
    }

    private func settingStatusText(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .enabled: return "已开启"
        case .disabled: return "已停用"
        case .notSupported: return "系统不支持"
        @unknown default: return "未知"
        }
    }

    private func settingStatusColor(_ setting: UNNotificationSetting) -> Color {
        switch setting {
        case .enabled: return AscendTheme.jade
        case .disabled: return .red
        case .notSupported: return .secondary
        @unknown default: return .secondary
        }
    }

    private func setTime(hour newHour: Int, minute newMinute: Int) {
        self.hour = newHour
        self.minute = newMinute
        applySchedule()
    }

    private func applySchedule() {
        Task {
            do {
                try await appState.configureNotifications(hour: hour, minute: minute)
                statusMessage = "已安排每日战报通知：\(String(format: "%02d:%02d", hour, minute))"
            } catch {
                statusMessage = error.localizedDescription
            }
            await refreshAuthStatus()
        }
    }

    private func refreshAuthStatus() async {
        permissionSnapshot = await appState.notificationPermissionSnapshot()
    }

    private func requestPermissionAndApply() {
        Task {
            do {
                try await appState.requestNotificationAuthorization()
                await refreshAuthStatus()
                if permissionSnapshot.isAuthorizedOrProvisional {
                    applySchedule()
                    statusMessage = "通知权限已获取，定时战报已安排"
                } else {
                    statusMessage = "通知权限申请未完成，请在系统弹窗中允许"
                }
            } catch {
                statusMessage = error.localizedDescription
                await refreshAuthStatus()
            }
        }
    }

    private func sendTestNotification() {
        isSendingTest = true
        Task {
            do {
                let snapshot = await appState.notificationPermissionSnapshot()
                guard snapshot.isAuthorizedOrProvisional else {
                    if snapshot.authorizationStatus == .notDetermined {
                        throw DigestScheduler.SchedulerError.notDetermined
                    } else {
                        throw DigestScheduler.SchedulerError.notificationDenied
                    }
                }
                try await appState.sendTestNotification()
                statusMessage = "测试通知已发送，请查看屏幕右上角横幅"
            } catch {
                statusMessage = error.localizedDescription
            }
            isSendingTest = false
            await refreshAuthStatus()
        }
    }

    private func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
