import SwiftUI

struct KnowledgeDetailView: View {
    @Environment(AppState.self) private var appState
    let node: KnowledgeNode
    let mastery: MasteryState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 顶部标题玉简
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(node.domain)
                            .font(.system(.caption, design: AscendTheme.titleDesign))
                            .foregroundStyle(.secondary)
                        Spacer()
                        CelestialBadge(
                            title: mastery.stage.rawValue,
                            style: badgeStyle(for: mastery.stage)
                        )
                    }

                    Text(node.name)
                        .font(.system(.title, design: AscendTheme.titleDesign))
                        .bold()
                }

                // 核心掌握度环与指标
                HStack(alignment: .center, spacing: 20) {
                    MasteryRingView(score: mastery.composite)

                    VStack(alignment: .leading, spacing: 10) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 10)], alignment: .leading, spacing: 10) {
                            statItem(title: "AI 置信度", value: "\(Int(mastery.confidence.rounded()))%")
                            statItem(title: "本周进益", value: "+\(appState.weeklyChange(for: node.id))")
                            statItem(title: "累积知验", value: "\(mastery.lifetimeXP) XP")
                        }

                        // 悟得真传提示框
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(AscendTheme.gold)
                                    .font(.caption2)
                                Text("悟得真意")
                                    .font(.system(.caption, design: AscendTheme.titleDesign))
                                    .bold()
                                    .foregroundStyle(AscendTheme.gold)
                            }

                            Text(appState.latestInsight(for: node.id) ?? "尚无已验证的悟得实据。继续在代码与笔记中深入实践或独立解决以凝练精义。")
                                .font(.system(.caption, design: AscendTheme.titleDesign))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(AscendTheme.gold.opacity(0.20), lineWidth: 0.8)
                        }
                    }
                }

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 五维雷达条带
                MasteryDimensionStrip(vector: mastery.vector)

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 历史实据与衰减轨迹
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        EvidenceLedgerView(nodeID: node.id)
                            .frame(width: 250)
                        MasteryTrajectoryView(currentScore: mastery.composite)
                            .frame(width: 280)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        EvidenceLedgerView(nodeID: node.id)
                        MasteryTrajectoryView(currentScore: mastery.composite)
                    }
                }

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 关联知识网络
                KnowledgeRelationsView(nodeID: node.id)

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 破境指引
                NextStageView(mastery: mastery)
            }
            .padding(22)
        }
        .background(FeaturePageBackground())
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: AscendTheme.titleDesign))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .rounded))
                .bold()
        }
    }

    private func badgeStyle(for stage: MasteryStage) -> CelestialBadgeStyle {
        switch stage {
        case .mastered, .connected: .gold
        case .integrated: .jade
        case .proficient: .astral
        case .advancing, .entry: .neutral
        }
    }
}
