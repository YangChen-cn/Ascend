import SwiftUI

struct KnowledgeGraphView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    let domainName: String
    let nodes: [KnowledgeNode]
    let score: (KnowledgeNode) -> Double
    let action: (KnowledgeNode) -> Void

    private var visibleNodes: [KnowledgeNode] {
        let nodeIDs = Set(nodes.map(\.id))
        let degrees = appState.knowledgeEdges.reduce(into: [UUID: Int]()) { result, edge in
            guard nodeIDs.contains(edge.sourceNodeID), nodeIDs.contains(edge.targetNodeID) else { return }
            result[edge.sourceNodeID, default: 0] += 1
            result[edge.targetNodeID, default: 0] += 1
        }
        return Array(nodes.sorted {
            let lhsDegree = degrees[$0.id, default: 0]
            let rhsDegree = degrees[$1.id, default: 0]
            if lhsDegree != rhsDegree { return lhsDegree > rhsDegree }
            return score($0) > score($1)
        }.prefix(7))
    }

    private var visibleEdges: [KnowledgeEdge] {
        let nodeIDs = Set(visibleNodes.map(\.id))
        return appState.knowledgeEdges.filter {
            nodeIDs.contains($0.sourceNodeID) && nodeIDs.contains($0.targetNodeID)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if visibleNodes.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.hexagongrid.fill")
                                .foregroundStyle(AscendTheme.gold)
                            Text("\(domainName) · 周天星座脉络图")
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

                            Text("此领域星图尚空 · 宿位以待")
                                .font(.system(.title3, design: .serif))
                                .bold()

                            Text("完成首次周天研习分析后，知识星宿与贯通灵脉将在此连结呈现。")
                                .font(.caption)
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
                        Text("\(domainName) · 周天星座脉络图")
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
                    let orbitDiameter = max(0, min(size.width - 48, size.height - 32))
                    let positionByNodeID = Dictionary(
                        uniqueKeysWithValues: zip(visibleNodes.map(\.id), positions).map { ($0, $1) }
                    )

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
                            .frame(width: orbitDiameter, height: orbitDiameter)
                            .position(center)

                        Circle()
                            .strokeBorder(
                                AscendTheme.gold.opacity(colorScheme == .dark ? 0.12 : 0.06),
                                style: StrokeStyle(lineWidth: 0.8, dash: [4, 6])
                            )
                            .frame(width: orbitDiameter * 0.62, height: orbitDiameter * 0.62)
                            .position(center)

                        // 灵脉连线（Glowing Ley-Lines Canvas）
                        Canvas { context, _ in
                            let connections: [(CGPoint, CGPoint)] = visibleEdges.compactMap { edge in
                                guard let source = positionByNodeID[edge.sourceNodeID],
                                      let target = positionByNodeID[edge.targetNodeID] else { return nil }
                                return (source, target)
                            }
                            for (source, target) in connections {
                                var path = Path()
                                path.move(to: source)
                                path.addLine(to: target)

                                // 灵脉底层辉光
                                context.stroke(
                                    path,
                                    with: .linearGradient(
                                        Gradient(colors: [
                                            AscendTheme.gold.opacity(0.6),
                                            AscendTheme.cobalt.opacity(0.4)
                                        ]),
                                        startPoint: source,
                                        endPoint: target
                                    ),
                                    lineWidth: 2.0
                                )
                            }
                        }

                        // 悬浮星宿节点
                        ForEach(Array(visibleNodes.enumerated()), id: \.element.id) { index, node in
                            GraphNodeButton(
                                node: node,
                                mastery: score(node),
                                isCenter: index == 0,
                                action: { action(node) }
                            )
                            .position(positions.indices.contains(index) ? positions[index] : .zero)
                        }
                    }
                }
                .frame(minHeight: 320, idealHeight: 420, maxHeight: 520)
            }
        }
    }

    private func graphPositions(in size: CGSize) -> [CGPoint] {
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.48)
        // Keep the 122 pt outer nodes and their aura inside the available graph area.
        let rx = max(0, (size.width - 170) / 2)
        let ry = max(0, (size.height - 160) / 2)
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

}
