import SwiftUI

struct DashboardHeaderView: View {
    @Environment(AppState.self) private var appState

    @State private var isExportSheetPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ResponsivePageHeader {
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
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } actions: {
                HStack(spacing: 10) {
                    Button(action: { isExportSheetPresented = true }) {
                        Label("研习画卷", systemImage: "scroll.fill")
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)

                    if appState.isCollectionSchedulerRunning {
                        CelestialBadge(
                            title: "自动采集中",
                            subtitle: "\(appState.sources.count) 源",
                            systemImage: "circle.circle.fill",
                            style: .jade
                        )
                    } else {
                        CelestialBadge(
                            title: appState.isCollecting ? "调度启动中" : "自动采集已停",
                            systemImage: "pause.circle",
                            style: .neutral
                        )
                    }
                }
            }

            Rectangle()
                .fill(AscendTheme.gold.opacity(0.30))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AscendTheme.gold)
                        .font(.caption)
                    Text("琅嬛玉简 · 今日真意")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(AscendTheme.gold)
                }

                Text(appState.currentDigest?.summary ?? "今日尚无已验证学习结果。分析真实活动后，这里会汇总全天成长、复习与下一步建议。")
                    .font(.body)
                    .lineSpacing(3)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(AscendTheme.gold.opacity(0.72))
                    .frame(width: 3)
            }
        }
        .sheet(isPresented: $isExportSheetPresented) {
            CelestialScrollExportSheet()
        }
    }
}
