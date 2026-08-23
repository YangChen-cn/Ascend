import SwiftUI

struct SettingsRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedSettingsSection) {
            Tab("通用", systemImage: "gearshape.fill", value: .general) {
                GeneralSettingsView()
            }
            Tab("数据源", systemImage: "externaldrive.fill", value: .sources) {
                DataSourcesSettingsView()
            }
            Tab("AI 接口", systemImage: "cpu.fill", value: .ai) {
                AIEndpointsSettingsView()
            }
            Tab("分析", systemImage: "slider.horizontal.3", value: .analysis) {
                AnalysisSettingsView()
            }
            Tab("隐私", systemImage: "hand.raised.fill", value: .privacy) {
                PrivacySettingsView()
            }
            Tab("通知", systemImage: "bell.fill", value: .notifications) {
                NotificationSettingsView()
            }
            Tab("外观", systemImage: "paintbrush.fill", value: .appearance) {
                AppearanceSettingsView()
            }
            Tab("关于", systemImage: "info.circle.fill", value: .about) {
                AboutSettingsView()
            }
        }
        .frame(width: 860, height: 600)
        .scenePadding()
    }
}
