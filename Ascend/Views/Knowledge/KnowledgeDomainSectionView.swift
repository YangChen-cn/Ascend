import SwiftUI

struct KnowledgeDomainSectionView: View {
    let group: KnowledgeDomainGroup
    let selectedNodeID: UUID?
    let score: (KnowledgeNode) -> Double
    let selectNode: (KnowledgeNode) -> Void
    let manageDomain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.system(.title2, design: AscendTheme.titleDesign))
                        .bold()
                    Text("独立星图 · \(group.nodes.count) 个知识点")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("管理领域", systemImage: "ellipsis.circle", action: manageDomain)
                    .buttonStyle(.bordered)
            }

            KnowledgeGraphView(
                domainName: group.name,
                nodes: group.nodes,
                score: score,
                action: selectNode
            )
            .panelCard()

            KnowledgeNodeGridView(
                domainName: group.name,
                nodes: group.nodes,
                selectedNodeID: selectedNodeID,
                score: score,
                action: selectNode
            )
        }
    }
}
