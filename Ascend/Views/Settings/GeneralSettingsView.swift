import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var launchAtLogin = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("运行") {
                Toggle("登录时启动知境录", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin, updateLoginItem)
                Toggle("自动采集学习活动", isOn: collectionBinding)
                if appState.isCollecting {
                    Stepper(
                        "采集间隔：\(appState.collectionIntervalMinutes) 分钟",
                        value: collectionIntervalBinding,
                        in: 1...60
                    )
                    LabeledContent(
                        "调度状态",
                        value: appState.isCollectionSchedulerRunning ? "自动采集中" : "正在启动"
                    )
                }
                Text("自动采集仅扫描已授权的 Git 与 Markdown 数据源，不会调用 AI。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("状态") {
                LabeledContent("本地知识点", value: appState.knowledgeNodes.count.formatted())
                LabeledContent("证据记录", value: appState.evidenceRecords.count.formatted())
                LabeledContent("终身经验", value: "\(appState.totalXP.formatted()) XP")
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .task { launchAtLogin = LoginItemService().isEnabled }
    }

    private var collectionBinding: Binding<Bool> {
        @Bindable var appState = appState
        return $appState.isCollecting
    }

    private var collectionIntervalBinding: Binding<Int> {
        @Bindable var appState = appState
        return $appState.collectionIntervalMinutes
    }

    private func updateLoginItem(_ oldValue: Bool, _ newValue: Bool) {
        guard oldValue != newValue else { return }
        do {
            try LoginItemService().setEnabled(newValue)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            launchAtLogin = oldValue
        }
    }
}
