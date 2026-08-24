import SwiftUI

struct ReviewEmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AscendTheme.jade.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(AscendTheme.jade)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(AscendTheme.isXuanqing ? "灵台明澈 · 暂无到期复习" : "暂无到期复习任务")
                        .font(.system(.title3, design: AscendTheme.titleDesign))
                        .bold()
                    Text("当前所有已知知窍的记忆留存率均在健康区间。系统基于 FSRS 间隔重复算法持续推演，将在到达最佳遗忘临界点时自动安排主动检索。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }

            HStack(spacing: 12) {
                Button {
                    appState.selectedSection = .knowledge
                } label: {
                    Label("浏览知识图谱", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)

                Button {
                    appState.selectedSection = .abilities
                } label: {
                    Label("查看能力地图", systemImage: "map")
                }
                .buttonStyle(.bordered)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
