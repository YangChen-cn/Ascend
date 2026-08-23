import SwiftUI

struct DashboardHeaderView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日知得")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                Label(appState.isCollecting ? "已配置 \(appState.sources.count) 个数据源" : "采集已暂停", systemImage: appState.isCollecting ? "circle.fill" : "pause.circle")
                    .font(.callout)
                    .foregroundStyle(appState.isCollecting ? AscendTheme.jade : .secondary)
            }
            Text(Date.now, format: .dateTime.year().month().day())
                .foregroundStyle(.secondary)
            Label("今日悟得", systemImage: "sparkles")
                .foregroundStyle(AscendTheme.cobalt)
                .padding(.top, 10)
            Text(appState.currentDigest?.summary ?? "完成首次分析后，这里会解释今天真正掌握了什么。")
                .font(.title3)
                .lineSpacing(5)
                .frame(maxWidth: 780, alignment: .leading)
        }
    }
}
