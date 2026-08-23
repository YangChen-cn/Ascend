import SwiftUI

struct KnowledgeGraphView: View {
    @Environment(AppState.self) private var appState

    private var visibleNodes: [KnowledgeNode] {
        Array(appState.knowledgeNodes.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if visibleNodes.isEmpty {
                ContentUnavailableView(
                    "知识图谱还是空的",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("完成首次分析后，知识点和关系会自动出现在这里。")
                )
                .frame(height: 260)
            } else {
                HStack {
                    SectionTitleView("知识星图")
                    Spacer()
                    Label("化用 80+", systemImage: "circle")
                    Label("融会 60–79", systemImage: "circle.dotted")
                    Label("入门 20–39", systemImage: "circle")
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                GeometryReader { proxy in
                    let size = proxy.size
                    let positions = graphPositions(in: size)
                    ZStack {
                        Canvas { context, _ in
                            guard let center = positions.first else { return }
                            for position in positions.dropFirst().prefix(max(0, visibleNodes.count - 1)) {
                                var path = Path()
                                path.move(to: center)
                                path.addLine(to: position)
                                context.stroke(path, with: .color(AscendTheme.cobalt.opacity(0.50)), lineWidth: 1.3)
                            }
                        }
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
                .frame(minHeight: 380)
            }
        }
    }

    private func graphPositions(in size: CGSize) -> [CGPoint] {
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.48)
        return [
            center,
            CGPoint(x: size.width * 0.20, y: size.height * 0.22),
            CGPoint(x: size.width * 0.18, y: size.height * 0.72),
            CGPoint(x: size.width * 0.80, y: size.height * 0.22),
            CGPoint(x: size.width * 0.82, y: size.height * 0.70),
            CGPoint(x: size.width * 0.51, y: size.height * 0.82)
        ]
    }

    private func select(_ node: KnowledgeNode) {
        appState.selectedKnowledgeNodeID = node.id
        appState.selectedSection = .knowledge
    }
}
