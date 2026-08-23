import SwiftUI

struct DashboardHeaderView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("洞府悟道")
                            .font(.system(.largeTitle, design: .serif))
                            .bold()
                        CelestialBadge(
                            title: "修为 Lv.\(appState.learnerLevel)",
                            subtitle: "\(appState.totalXP) XP",
                            systemImage: "flame.fill",
                            style: .gold
                        )
                    }

                    Text(Date.now, format: .dateTime.year().month().day().weekday(.wide))
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    if appState.isCollecting {
                        CelestialBadge(
                            title: "周天巡察中",
                            subtitle: "\(appState.sources.count) 源",
                            systemImage: "circle.circle.fill",
                            style: .jade
                        )
                    } else {
                        CelestialBadge(
                            title: "巡察暂歇",
                            systemImage: "pause.circle",
                            style: .neutral
                        )
                    }
                }
            }

            Divider()
                .overlay {
                    AscendTheme.gold.opacity(0.20)
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AscendTheme.gold)
                        .font(.caption)
                    Text("琅嬛玉简 · 今日真意")
                        .font(.system(.subheadline, design: .serif))
                        .bold()
                        .foregroundStyle(AscendTheme.gold)
                }

                Text(appState.currentDigest?.summary ?? "万法归宗，行而不辍。待今日灵机初定，AI 将在此阐析你所悟得的真实精义。")
                    .font(.system(.body, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: 820, alignment: .leading)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.03) : AscendTheme.gold.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AscendTheme.gold.opacity(0.25), lineWidth: 0.8)
            }
        }
    }
}
