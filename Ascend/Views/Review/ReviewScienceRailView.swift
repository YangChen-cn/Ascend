import SwiftUI

struct ReviewScienceRailView: View {
    @Environment(AppState.self) private var appState

    private var trackedNodeCount: Int {
        appState.memoryStates.count
    }

    private var averageRetention: Double? {
        let validRetentions = appState.knowledgeNodes.compactMap { appState.currentRetention(for: $0.id) }
        guard !validRetentions.isEmpty else { return nil }
        return validRetentions.reduce(0, +) / Double(validRetentions.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // FSRS 记忆法则卡片
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "scroll.fill")
                        .foregroundStyle(AscendTheme.gold)
                    Text(AscendTheme.isXuanqing ? "温故法轨 · 记忆之律" : "FSRS 记忆科学原则")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()
                    Spacer()
                    CelestialBadge(title: "科学", style: .astral)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("主动回忆要点有助于加深记忆印象，建立稳固连接。", systemImage: "brain.head.profile")
                        .font(.caption)
                    Label("系统依据历史回忆表现，用 FSRS 动态安排下一次温故。", systemImage: "timer")
                        .font(.caption)
                    Label("温故后自评「忘了 / 有点模糊 / 记得 / 很熟」，FSRS 动态推演下次间隔。", systemImage: "slider.horizontal.3")
                        .font(.caption)
                        .help("四档自评对应 FSRS 的 Again / Hard / Good / Easy 评分")
                    Label("温故回忆完全在本地运行，0 次 AI 调用与 Token 开销。", systemImage: "bolt.shield.fill")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .sectionSurface(.grouped)

            // 记忆健康态势卡片
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(AscendTheme.jade)
                    Text(AscendTheme.isXuanqing ? "灵台留存 · 记忆全景" : "记忆保持态势")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()
                    Spacer()
                    if let avg = averageRetention {
                        CelestialBadge(
                            title: retentionLevelTitle(avg),
                            style: avg >= 80 ? .jade : (avg >= 60 ? .gold : .cinnabar)
                        )
                        .help("平均记忆可提取率 \(Int(avg.rounded()))%")
                    } else {
                        CelestialBadge(title: "尚无数据", style: .astral)
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FSRS 纳管知窍")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(trackedNodeCount)")
                            .font(.system(.title3, design: .rounded))
                            .bold()
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("整体记忆状态")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(averageRetention.map { retentionLevelTitle($0) } ?? "—")
                            .font(.system(.title3, design: AscendTheme.titleDesign))
                            .bold()
                            .foregroundStyle(averageRetention != nil ? AscendTheme.jade : .secondary)
                    }
                }
                .padding(.vertical, 4)

                if !appState.forgettingProjections.isEmpty {
                    Divider()
                        .overlay(AscendTheme.gold.opacity(0.12))

                    Text(AscendTheme.isXuanqing ? "遗忘预警知窍" : "衰减最快的知识点")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.secondary)

                    ForEach(appState.forgettingProjections.prefix(3)) { projection in
                        HStack {
                            Text(projection.node.name)
                                .font(.caption)
                                .bold()
                                .lineLimit(1)
                            Spacer()
                            Text("记忆自然回落")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .help("当前掌握较历史高点回落 \(projection.scoreLoss) 分，温故即可恢复")
                        }
                    }
                }
            }
            .sectionSurface(.grouped)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 整体记忆状态以语义呈现，百分比留在 tooltip
    private func retentionLevelTitle(_ value: Double) -> String {
        switch value {
        case ..<60: "需要温故"
        case ..<85: "略有生疏"
        default: "记得牢固"
        }
    }
}
