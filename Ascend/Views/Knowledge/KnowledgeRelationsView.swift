import SwiftUI

struct KnowledgeRelationsView: View {
    @Environment(AppState.self) private var appState
    let nodeID: UUID

    private var related: [KnowledgeNode] {
        let ids = appState.knowledgeEdges.compactMap { edge -> UUID? in
            if edge.sourceNodeID == nodeID { return edge.targetNodeID }
            if edge.targetNodeID == nodeID { return edge.sourceNodeID }
            return nil
        }
        return ids.compactMap(appState.node(for:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitleView("知脉")
            HStack(spacing: 10) {
                ForEach(related) { node in
                    Button(node.name, action: { appState.selectedKnowledgeNodeID = node.id })
                        .buttonStyle(.bordered)
                    if node.id != related.last?.id {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                if related.isEmpty {
                    Text("AI 将在后续分析中补充前置、相生与下游知脉")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
