import SwiftUI

struct KnowledgeNodeGridView: View {
    let nodes: [KnowledgeNode]
    let selectedNodeID: UUID?
    let score: (KnowledgeNode) -> Double
    let action: (KnowledgeNode) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundStyle(AscendTheme.gold)
                    Text(AscendTheme.isXuanqing ? "周天知窍 · 知识点名录" : "知识点名录")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()
                }

                Spacer()

                Text("共 \(nodes.count) 处知窍")
                    .font(.system(.caption, design: AscendTheme.titleDesign))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                ForEach(nodes) { node in
                    let nodeScore = score(node)
                    let stage = MasteryStage.stage(for: nodeScore)
                    let isSelected = selectedNodeID == node.id

                    Button(action: { action(node) }) {
                        HStack(spacing: 12) {
                            // 掌握度微型圆环
                            ZStack {
                                Circle()
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 4)
                                Circle()
                                    .trim(from: 0, to: max(0.01, nodeScore / 100))
                                    .stroke(
                                        AscendTheme.isXuanqing ? AscendTheme.jadeGradient : AscendTheme.astralGradient,
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                Text(Int(nodeScore.rounded()).formatted())
                                    .font(.system(.callout, design: .rounded))
                                    .bold()
                                    .foregroundStyle(AscendTheme.isXuanqing ? AscendTheme.gold : .primary)
                            }
                            .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(node.name)
                                    .font(.system(.headline, design: AscendTheme.titleDesign))
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Text(node.domain)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("·")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    CelestialBadge(
                                        title: stage.rawValue,
                                        style: badgeStyle(for: stage)
                                    )
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundStyle(isSelected ? AscendTheme.jade : .secondary.opacity(0.5))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? (AscendTheme.isXuanqing ? AscendTheme.jade.opacity(0.12) : AscendTheme.cobalt.opacity(0.08)) : Color.primary.opacity(0.025))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? (AscendTheme.isXuanqing ? AscendTheme.gold : AscendTheme.cobalt)
                                        : (AscendTheme.isXuanqing ? AscendTheme.gold.opacity(0.15) : AscendTheme.border(for: colorScheme)),
                                    lineWidth: isSelected ? 1.5 : 0.8
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("在检查器中打开掌握详情")
                }
            }
        }
        .panelCard()
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
