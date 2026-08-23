import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.light.rawValue
    @AppStorage("visualTheme") private var visualThemeRaw = VisualTheme.xuanqing.rawValue

    var body: some View {
        Form {
            Section("外观") {
                Picker("风格", selection: $visualThemeRaw) {
                    ForEach(VisualTheme.allCases) { theme in
                        VStack(alignment: .leading) {
                            Text(theme.title)
                            Text(theme.description)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .tag(theme.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                Picker("主题", selection: $appearanceModeRaw) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                Text("默认使用玄青明亮主题；所有状态色同时提供文字、图标或线型提示，不只依赖颜色。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
