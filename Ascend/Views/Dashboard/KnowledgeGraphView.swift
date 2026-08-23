import SwiftUI

struct KnowledgeGraphView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var visibleNodes: [KnowledgeNode] {
        Array(appState.knowledgeNodes.prefix(7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if visibleNodes.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.hexagongrid.fill")
                                .foregroundStyle(AscendTheme.gold)
                            Text("周天灵脉星图")
                                .font(.system(.headline, design: .serif))
                                .bold()
                        }
                        Spacer()
                        CelestialBadge(title: "太虚初辟", style: .astral)
                    }

                    ZStack {
                        // 仙家星空虚影与星轨
                        Circle()
                            .strokeBorder(
                                AscendTheme.cobalt.opacity(colorScheme == .dark ? 0.20 : 0.10),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 8])
                            )
                            .frame(width: 220, height: 220)

                        Circle()
                            .strokeBorder(
                                AscendTheme.gold.opacity(colorScheme == .dark ? 0.15 : 0.08),
                                style: StrokeStyle(lineWidth: 0.8, dash: [4, 6])
                            )
                            .frame(width: 130, height: 130)

                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(AscendTheme.gold.opacity(0.12))
                                    .frame(width: 54, height: 54)
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                    .foregroundStyle(AscendTheme.gold)
                            }

                            Text("周天星图尚空 · 宿位以待")
                                .font(.system(.title3, design: .serif))
                                .bold()

                            Text("完成首次周天研习分析后，知识星宿与贯通灵脉将在此连结呈现。")
                                .font(.system(.caption, design: .serif))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 380)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.hexagongrid.fill")
                            .foregroundStyle(AscendTheme.gold)
                        Text("周天灵脉星图")
                            .font(.system(.headline, design: .serif))
                            .bold()
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        CelestialBadge(title: "化用通达", subtitle: "80+", style: .gold)
                        CelestialBadge(title: "融会", subtitle: "60–79", style: .jade)
                        CelestialBadge(title: "通晓", subtitle: "40–59", style: .astral)
                    }
                }

                GeometryReader { proxy in
                    let size = proxy.size
                    let positions = graphPositions(in: size)
                    let center = positions.first ?? CGPoint(x: size.width / 2, y: size.height / 2)

                    ZStack {
                        // 星轨同心圆（Celestial Orbit Rings）
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        AscendTheme.cobalt.opacity(colorScheme == .dark ? 0.20 : 0.10),
                                        AscendTheme.jade.opacity(colorScheme == .dark ? 0.15 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 8])
                            )
                            .frame(width: size.width * 0.72, height: size.width * 0.72)
                            .position(center)

                        Circle()
                            .strokeBorder(
                                AscendTheme.gold.opacity(colorScheme == .dark ? 0.12 : 0.06),
                                style: StrokeStyle(lineWidth: 0.8, dash: [4, 6])
                            )
                            .frame(width: size.width * 0.44, height: size.width * 0.44)
                            .position(center)

                        // 灵脉连线（Glowing Ley-Lines Canvas）
                        Canvas { context, _ in
                            for position in positions.dropFirst().prefix(max(0, visibleNodes.count - 1)) {
                                var path = Path()
                                path.move(to: center)
                                path.addLine(to: position)

                                // 灵脉底层辉光
                                context.stroke(
                                    path,
                                    with: .linearGradient(
                                        Gradient(colors: [
                                            AscendTheme.gold.opacity(0.6),
                                            AscendTheme.cobalt.opacity(0.4)
                                        ]),
                                        startPoint: center,
                                        endPoint: position
                                    ),
                                    lineWidth: 2.0
                                )
                            }
                        }

                        // 悬浮星宿节点
                        ForEach(Array(visibleNodes.enumerated()), id: \.element.id) { index, node in
                            GraphNodeButton(
                                node: node,
                                mastery: appState.mastery(for: node.id)?.composite ?? 0,
                                isCenter: index == 0,
                                action: { select(node) }
                            )
                            .position(positions.indices.contains(index) ? positions[index] : .zero)
                        }
                    }
                }
                .frame(minHeight: 400)
            }
        }
    }

    private func graphPositions(in size: CGSize) -> [CGPoint] {
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.48)
        let rx = size.width * 0.36
        let ry = size.height * 0.36
        return [
            center,
            CGPoint(x: center.x - rx * 0.85, y: center.y - ry * 0.70),
            CGPoint(x: center.x + rx * 0.85, y: center.y - ry * 0.70),
            CGPoint(x: center.x - rx * 0.95, y: center.y + ry * 0.35),
            CGPoint(x: center.x + rx * 0.95, y: center.y + ry * 0.35),
            CGPoint(x: center.x - rx * 0.35, y: center.y + ry * 0.85),
            CGPoint(x: center.x + rx * 0.35, y: center.y + ry * 0.85)
        ]
    }

    private func select(_ node: KnowledgeNode) {
        appState.selectedKnowledgeNodeID = node.id
        appState.selectedSection = .knowledge
    }
}
