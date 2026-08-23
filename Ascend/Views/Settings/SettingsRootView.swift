import SwiftUI

struct SettingsRootView: View {
    @State private var selection = SettingsSection.general

    var body: some View {
        TabView(selection: $selection) {
            Tab("通用", systemImage: "gearshape", value: .general) {
                GeneralSettingsView()
            }
            Tab("数据源", systemImage: "externaldrive", value: .sources) {
                DataSourcesSettingsView()
            }
            Tab("AI 接口", systemImage: "cpu", value: .ai) {
                AIEndpointsSettingsView()
            }
            Tab("隐私", systemImage: "hand.raised", value: .privacy) {
                PrivacySettingsView()
            }
            Tab("通知", systemImage: "bell", value: .notifications) {
                NotificationSettingsView()
            }
            Tab("外观", systemImage: "paintbrush", value: .appearance) {
                AppearanceSettingsView()
            }
        }
        .frame(width: 820, height: 560)
        .scenePadding()
    }
}
