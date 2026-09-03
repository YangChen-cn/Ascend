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
    let snapshot: ConstellationDomainRenderSnapshot
    let selectedNodeID: UUID?
    let selectNode: (UUID?) -> Void
    var openNode: ((UUID) -> Void)? = nil
    let persistPosition: (UUID, CGPoint) -> Void
    let resetPersistedLayout: () -> Void
    let manageDomain: () -> Void

    @State private var viewMode: KnowledgeSectionViewMode = .constellation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    domainTitle
                    Spacer(minLength: 12)
                    viewControls
                }

                VStack(alignment: .leading, spacing: 12) {
                    domainTitle
                    HStack(spacing: 12) {
                        Picker("视图模式", selection: $viewMode) {
                            ForEach(KnowledgeSectionViewMode.allCases) { mode in
                                Label(mode.rawValue, systemImage: mode.icon)
                                    .tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)

                        Button("管理领域", systemImage: "ellipsis.circle", action: manageDomain)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                            .help("管理领域")
                    }
                }
            }

            switch viewMode {
            case .constellation:
                CelestialConstellationGraphView(
                    snapshot: snapshot,
                    selectedNodeID: selectedNodeID,
                    onSelectNode: selectNode,
                    onOpenNode: openNode,
                    onPersistPosition: persistPosition,
                    onResetPersistedLayout: resetPersistedLayout
                )
            case .matrix:
                KnowledgeNodeGridView(
                    domainName: snapshot.name,
                    nodes: snapshot.nodes,
                    selectedNodeID: selectedNodeID,
                    action: { nodeID in
                        openNode?(nodeID)
                    }
                )
            case .hybrid:
                VStack(spacing: 16) {
                    CelestialConstellationGraphView(
                        snapshot: snapshot,
                        selectedNodeID: selectedNodeID,
                        onSelectNode: selectNode,
                        onOpenNode: openNode,
                        onPersistPosition: persistPosition,
                        onResetPersistedLayout: resetPersistedLayout
                    )

                    KnowledgeNodeGridView(
                        domainName: snapshot.name,
                        nodes: snapshot.nodes,
                        selectedNodeID: selectedNodeID,
                        action: { nodeID in
                            openNode?(nodeID)
                        }
                    )
                }
            }
        }
    }

    private var domainTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.name)
                .font(.system(.title2, design: AscendTheme.titleDesign))
                .bold()
            Text("独立星脉 · \(snapshot.nodes.count) 个知窍")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var viewControls: some View {
        HStack(spacing: 12) {
            Picker("视图模式", selection: $viewMode) {
                ForEach(KnowledgeSectionViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 240)

            Button("管理领域", systemImage: "ellipsis.circle", action: manageDomain)
                .buttonStyle(.bordered)
        }
    }
}
