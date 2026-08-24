import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppearancePreferences.self) private var appearancePreferences

    var body: some View {
        @Bindable var preferences = appearancePreferences

        Form {
            Section("视觉风格体系") {
                Picker("视觉主题", selection: $preferences.visualTheme) {
                    ForEach(VisualTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    HStack(spacing: -5) {
                        ForEach(Array(previewColors.enumerated()), id: \.offset) { _, color in
                            Circle()
                                .fill(color)
                                .frame(width: 18, height: 18)
                                .overlay { Circle().stroke(Color.primary.opacity(0.14), lineWidth: 0.7) }
                        }
                    }
                    .frame(width: 46)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(preferences.visualTheme == .xuanqing ? "玄青 · 道家仙韵" : "清简 · 原生现代")
                            .font(.headline)
                        Text(preferences.visualTheme.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("深浅明暗模式") {
                Picker("明暗模式", selection: $preferences.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("切换风格或明暗后将即时生效，所有图表与星脉连线均无缝适配。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var previewColors: [Color] {
        appearancePreferences.visualTheme == .xuanqing
            ? [Color(red: 0.978, green: 0.965, blue: 0.925), AscendTheme.jade, AscendTheme.gold]
            : [Color.white, Color(red: 0.10, green: 0.43, blue: 0.83), Color(red: 0.34, green: 0.38, blue: 0.44)]
    }
}
