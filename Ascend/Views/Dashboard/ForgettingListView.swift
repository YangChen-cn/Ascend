import SwiftUI

struct ForgettingListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .foregroundStyle(AscendTheme.amber)
                    Text("记忆保持 · 到期复习")
                        .font(.system(.headline, design: .serif))
                        .bold()
                }
                Spacer()
                if !appState.forgettingProjections.isEmpty {
                    CelestialBadge(
                        title: "\(appState.forgettingProjections.count) 待巩固",
                        style: .cinnabar
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
                            .font(.system(.subheadline, design: .serif))
                            .bold()
                        Text("当前所悟知识暂无遗忘之虞，道法精进自然。")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                ForEach(appState.forgettingProjections.prefix(3)) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.node.name)
                                .font(.system(.callout, design: .serif))
                                .bold()
                            Spacer()
                            Text("-\(item.scoreLoss) 掌握")
                                .font(.system(.caption, design: .rounded))
                                .bold()
                                .foregroundStyle(AscendTheme.amber)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 5)
                                Capsule()
                                    .fill(AscendTheme.cinnabarGradient)
                                    .frame(width: max(4, proxy.size.width * CGFloat(min(100, item.retention)) / 100), height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
