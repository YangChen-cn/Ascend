import SwiftUI

struct GrowthOverviewView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(AscendTheme.gold)
                    Text("今日悟得 · 道业精进")
                        .font(.system(.headline, design: .serif))
                        .bold()
                }
                Spacer()
                if !appState.todayXPGains.isEmpty {
                    CelestialBadge(
                        title: "+\(appState.todayXPGains.reduce(0) { $0 + $1.xp }) XP",
                        style: .gold
                    )
                }
            }

            if appState.todayMasteryChanges.isEmpty && appState.todayXPGains.isEmpty {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AscendTheme.gold.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "sparkle")
                            .font(.title2)
                            .foregroundStyle(AscendTheme.gold)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("静候灵机 · 暂无浮沉")
                            .font(.body)
                            .bold()
                        Text("万丈高楼起于垒土。完成周天巡察与首次悟道分析后，此间将展现知验与五维掌握度之精进。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }
                .padding(.vertical, 8)
            } else {
                HStack(alignment: .top, spacing: 24) {
                    MasteryChangeListView(metrics: appState.todayMasteryChanges)
                        .frame(maxWidth: .infinity)
                    Divider()
                        .overlay(AscendTheme.gold.opacity(0.15))
                    XPGainLedgerView(items: appState.todayXPGains)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
