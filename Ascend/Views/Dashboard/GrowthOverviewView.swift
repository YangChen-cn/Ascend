import SwiftUI

struct GrowthOverviewView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.todayMasteryChanges.isEmpty && appState.todayXPGains.isEmpty {
            ContentUnavailableView(
                "今天还没有成长记录",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("添加数据源并完成首次分析后，这里会显示掌握度和 XP 变化。")
            )
            .frame(minHeight: 190)
        } else {
            HStack(alignment: .top, spacing: 30) {
                MasteryChangeListView(metrics: appState.todayMasteryChanges)
                    .frame(maxWidth: .infinity)
                Divider()
                XPGainLedgerView(items: appState.todayXPGains)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
