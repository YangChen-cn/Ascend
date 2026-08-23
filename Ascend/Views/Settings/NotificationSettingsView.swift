import SwiftUI

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("digestHour") private var hour = AppConstants.defaultDigestHour
    @AppStorage("digestMinute") private var minute = AppConstants.defaultDigestMinute
    @State private var message: String?

    var body: some View {
        Form {
            Section("每日报告") {
                LabeledContent("生成时间") {
                    HStack {
                        Picker("小时", selection: $hour) {
                            ForEach(0..<24, id: \.self) { Text($0.formatted()).tag($0) }
                        }
                        Picker("分钟", selection: $minute) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text($0.formatted()).tag($0) }
                        }
                    }
                }
                Button("启用并更新通知", systemImage: "bell.badge", action: configure)
                Text("电脑睡眠或知境录未运行时，将在下次激活后补做分析；登录启动可提高准时性。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let message { Section { Text(message) } }
        }
        .formStyle(.grouped)
    }

    private func configure() {
        Task {
            do {
                try await appState.configureNotifications(hour: hour, minute: minute)
                message = "已安排每天 \(hour.formatted()):\(minute.formatted(.number.precision(.integerLength(2)))) 的通知"
            } catch {
                message = error.localizedDescription
            }
        }
    }
}
