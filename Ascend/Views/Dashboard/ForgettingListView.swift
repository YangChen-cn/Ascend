import SwiftUI

struct ForgettingListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.circle.fill")
                        .foregroundStyle(AscendTheme.jade)
                    Text("记忆温故")
                        .font(.system(.headline, design: .serif))
                        .bold()
                }
                Spacer()
                if !appState.forgettingProjections.isEmpty {
                    CelestialBadge(
                        title: "\(appState.forgettingProjections.count) 则可温故",
                        style: .jade
                    )
                }
            }

            if appState.forgettingProjections.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(AscendTheme.jade)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("灵台清明 · 道基稳固")
                            .font(.subheadline)
                            .bold()
                        Text("当前所悟知识暂无遗忘之虞，道法精进自然。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                ForEach(appState.forgettingProjections.prefix(3)) { item in
                    HStack {
                        Text(item.node.name)
                            .font(.callout)
                            .bold()
                        Spacer()
                        Text("记忆自然回落")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("较历史高点回落 \(item.scoreLoss) 分，温故即可恢复")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
