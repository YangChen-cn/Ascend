import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("digestHour") private var hour = AppConstants.defaultDigestHour
    @AppStorage("digestMinute") private var minute = AppConstants.defaultDigestMinute
    @AppStorage("digestNotificationsEnabled") private var notificationsEnabled = true

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var statusMessage: String?
    @State private var isSendingTest = false

    private let minuteOptions = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    var body: some View {
        Form {
            // MARK: - 1. 每日研习战报推送
            Section {
                Toggle("启用每日研习战报与温故提醒", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            applySchedule()
                        } else {
                            statusMessage = "已关闭每日通知推送"
                        }
                    }

                if notificationsEnabled {
                    LabeledContent("每日推送时刻") {
                        HStack(spacing: 8) {
                            // 原生下拉菜单：小时
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

                            // 原生下拉菜单：分钟
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
                                .fill(notificationsEnabled ? AscendTheme.jade : .secondary)
                                .frame(width: 6, height: 6)
                            Text("每天 \(String(format: "%02d:%02d", hour, minute)) 定时推送")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(notificationsEnabled ? AscendTheme.jade : .secondary)
                        }
                    }
                }
            } header: {
                Text("每日研习战报推送")
            } footer: {
                Text("知境录会在每天指定时刻自动汇总当日研习成果，生成修真研习心得，并通过系统通知提醒你及时温故知新。电脑休眠或未运行时将在下次激活后补做分析。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - 2. 战报内容构成
            Section("战报所含研习维度") {
                LabeledContent("今日知得与经验", value: "汇总当日新增知识点、掌握度与 XP 实据")
                LabeledContent("艾宾浩斯温故预警", value: "根据记忆衰退曲线精准提醒临界概念")
                LabeledContent("修真境界跃升", value: "各领域修为突破与研习挑战达成")
            }

            // MARK: - 3. 权限与测试
            Section("系统权限与测试") {
                HStack {
                    Text("系统通知权限状态")
                    Spacer()
                    Text(authStatusText)
                        .font(.caption.bold())
                        .foregroundStyle(authStatusColor)
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

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(statusMessage.contains("失败") || statusMessage.contains("未开启") ? .red : AscendTheme.jade)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await refreshAuthStatus()
        }
    }

    private var authStatusText: String {
        switch authorizationStatus {
        case .authorized: "✅ 已授权允许"
        case .provisional: "⚡ 临时授权"
        case .denied: "❌ 已拒绝/未开启"
        case .notDetermined: "⏳ 尚未授权"
        @unknown default: "未知"
        }
    }

    private var authStatusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional: AscendTheme.jade
        case .denied: .red
        case .notDetermined: .orange
        @unknown default: .secondary
        }
    }

    private func setTime(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
        applySchedule()
    }

    private func applySchedule() {
        guard notificationsEnabled else { return }
        Task {
            do {
                try await appState.configureNotifications(hour: hour, minute: minute)
                authorizationStatus = await appState.checkNotificationAuthorizationStatus()
                let timeStr = String(format: "%02d:%02d", hour, minute)
                statusMessage = "已安排每天 \(timeStr) 定时推送"
            } catch {
                statusMessage = error.localizedDescription
                authorizationStatus = await appState.checkNotificationAuthorizationStatus()
            }
        }
    }

    private func requestPermissionAndApply() {
        Task {
            do {
                try await appState.configureNotifications(hour: hour, minute: minute)
                authorizationStatus = await appState.checkNotificationAuthorizationStatus()
                statusMessage = "通知权限已获取，已安排每天 \(String(format: "%02d:%02d", hour, minute)) 定时推送"
            } catch {
                statusMessage = error.localizedDescription
                authorizationStatus = await appState.checkNotificationAuthorizationStatus()
            }
        }
    }

    private func sendTestNotification() {
        isSendingTest = true
        Task {
            do {
                try await appState.sendTestNotification()
                authorizationStatus = await appState.checkNotificationAuthorizationStatus()
                statusMessage = "测试通知已发送，请查看屏幕右上角"
            } catch {
                statusMessage = error.localizedDescription
                authorizationStatus = await appState.checkNotificationAuthorizationStatus()
            }
            isSendingTest = false
        }
    }

    private func refreshAuthStatus() async {
        authorizationStatus = await appState.checkNotificationAuthorizationStatus()
    }

    private func openSystemNotificationSettings() {
        // 尝试多种 macOS 系统设置 URL Scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }
}
