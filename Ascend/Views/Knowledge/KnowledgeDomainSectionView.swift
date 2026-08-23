import SwiftUI

enum KnowledgeSectionViewMode: String, CaseIterable, Identifiable {
    case constellation = "星图拓扑"
    case matrix = "知脉矩阵"
    case hybrid = "全览"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .constellation: "sparkles"
        case .matrix: "square.grid.2x2"
        case .hybrid: "rectangle.split.2x1"
        }
    }
}

struct KnowledgeDomainSectionView: View {
    let group: KnowledgeDomainGroup
    let selectedNodeID: UUID?
    let score: (KnowledgeNode) -> Double
    let selectNode: (KnowledgeNode) -> Void
    var openNode: ((KnowledgeNode) -> Void)? = nil
    let manageDomain: () -> Void

    @State private var viewMode: KnowledgeSectionViewMode = .constellation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.system(.title2, design: AscendTheme.titleDesign))
                        .bold()
                    Text("独立星脉 · \(group.nodes.count) 个知窍")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("视图模式", selection: $viewMode) {
                    ForEach(KnowledgeSectionViewMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Button("管理领域", systemImage: "ellipsis.circle", action: manageDomain)
                    .buttonStyle(.bordered)
            }

            switch viewMode {
            case .constellation:
                CelestialConstellationGraphView(
                    domainName: group.name,
                    nodes: group.nodes,
                    selectedNodeID: selectedNodeID,
                    score: score,
                    onSelectNode: selectNode,
                    onOpenNode: openNode
                )
            case .matrix:
                KnowledgeNodeGridView(
                    domainName: group.name,
                    nodes: group.nodes,
                    selectedNodeID: selectedNodeID,
                    score: score,
                    action: { node in
                        selectNode(node)
                        openNode?(node)
                    }
                )
            case .hybrid:
                VStack(spacing: 16) {
                    CelestialConstellationGraphView(
                        domainName: group.name,
                        nodes: group.nodes,
                        selectedNodeID: selectedNodeID,
                        score: score,
                        onSelectNode: selectNode,
                        onOpenNode: openNode
                    )

                    KnowledgeNodeGridView(
                        domainName: group.name,
                        nodes: group.nodes,
                        selectedNodeID: selectedNodeID,
                        score: score,
                        action: { node in
                            selectNode(node)
                            openNode?(node)
                        }
                    )
                }
            }
        }
    }
}

