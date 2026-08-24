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
                        .font(.system(.caption, design: AscendTheme.titleDesign))
                    Label("系统依据历史回忆表现，用 FSRS 动态安排下一次温故。", systemImage: "timer")
                        .font(.system(.caption, design: AscendTheme.titleDesign))
                    Label("自评 Again / Hard / Good / Easy，FSRS 动态推演下次间隔。", systemImage: "slider.horizontal.3")
                        .font(.system(.caption, design: AscendTheme.titleDesign))
                    Label("温故回忆完全在本地运行，0 次 AI 调用与 Token 开销。", systemImage: "bolt.shield.fill")
                        .font(.system(.caption, design: AscendTheme.titleDesign))
                }
                .foregroundStyle(.secondary)
            }
            .panelCard()

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
                            title: "\(Int(avg.rounded()))% 保持",
                            style: avg >= 80 ? .jade : (avg >= 60 ? .gold : .cinnabar)
                        )
                    } else {
                        CelestialBadge(title: "尚无数据", style: .astral)
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FSRS 纳管知窍")
                            .font(.system(.caption2, design: .serif))
                            .foregroundStyle(.secondary)
                        Text("\(trackedNodeCount)")
                            .font(.system(.title3, design: .rounded))
                            .bold()
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("预计平均可提取率")
                            .font(.system(.caption2, design: .serif))
                            .foregroundStyle(.secondary)
                        Text(averageRetention.map { String(format: "%.1f%%", $0) } ?? "—")
                            .font(.system(.title3, design: .rounded))
                            .bold()
                            .foregroundStyle(averageRetention != nil ? AscendTheme.jade : .secondary)
                    }
                }
                .padding(.vertical, 4)

                if !appState.forgettingProjections.isEmpty {
                    Divider()
                        .overlay(AscendTheme.gold.opacity(0.12))

                    Text(AscendTheme.isXuanqing ? "遗忘预警知窍" : "衰减最快的知识点")
                        .font(.system(.caption, design: AscendTheme.titleDesign))
                        .bold()
                        .foregroundStyle(.secondary)

                    ForEach(appState.forgettingProjections.prefix(3)) { projection in
                        HStack {
                            Text(projection.node.name)
                                .font(.system(.caption, design: .serif))
                                .bold()
                                .lineLimit(1)
                            Spacer()
                            Text("-\(projection.scoreLoss) 掌握")
                                .font(.system(.caption2, design: .rounded))
                                .bold()
                                .foregroundStyle(AscendTheme.amber)
                        }
                    }
                }
            }
            .panelCard()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
