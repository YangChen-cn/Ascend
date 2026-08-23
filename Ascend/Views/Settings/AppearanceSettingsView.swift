import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.light.rawValue
    @AppStorage("visualTheme") private var visualThemeRaw = VisualTheme.defaultTheme.rawValue

    var body: some View {
        Form {
            Section("视觉风格体系") {
                VStack(alignment: .leading, spacing: 14) {
                    themeOptionCard(
                        theme: .contemporary,
                        title: "清简 · 纯白现代",
                        desc: "纯净现代白与深空黑、苹果极简设计、无衬线字体，克制且专注。",
                        colors: [Color.white, Color(red: 0.12, green: 0.45, blue: 0.92), Color(red: 0.06, green: 0.65, blue: 0.45)]
                    )

                    themeOptionCard(
                        theme: .xuanqing,
                        title: "玄青 · 道家仙韵",
                        desc: "玄青墨玉、素绢云宣、九天流金、周天星斗灵脉与书法衬线，空灵古雅。",
                        colors: [Color(red: 0.978, green: 0.965, blue: 0.925), Color(red: 0.08, green: 0.72, blue: 0.55), Color(red: 0.95, green: 0.72, blue: 0.22)]
                    )
                }
                .padding(.vertical, 4)
            }

            Section("深浅明暗模式") {
                Picker("明暗模式", selection: $appearanceModeRaw) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode.rawValue)
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

    private func themeOptionCard(theme: VisualTheme, title: String, desc: String, colors: [Color]) -> some View {
        let isSelected = visualThemeRaw == theme.rawValue

        return Button(action: { visualThemeRaw = theme.rawValue }) {
            HStack(spacing: 14) {
                // 色彩预览小圆斑
                HStack(spacing: -6) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, col in
                        Circle()
                            .fill(col)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.8)
                            }
                    }
                }
                .frame(width: 50)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AscendTheme.jade)
                        }
                    }
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AscendTheme.jade.opacity(0.10) : Color.primary.opacity(0.02))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? AscendTheme.jade : Color.primary.opacity(0.10), lineWidth: isSelected ? 1.5 : 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}
