import SwiftUI

struct KnowledgeGraphScreen: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var isInspectorPresented = false

    private var filteredNodes: [KnowledgeNode] {
        guard !searchText.isEmpty else { return appState.knowledgeNodes }
        return appState.knowledgeNodes.filter {
            $0.name.localizedStandardContains(searchText) || $0.domain.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            FeaturePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeaderView(
                        "知识图谱",
                        subtitle: "循知脉而观全局，点选知识点可展开掌握详情。",
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )

                    if appState.knowledgeNodes.isEmpty {
                        KnowledgeGraphEmptyStateView()
                    } else if filteredNodes.isEmpty {
                        ContentUnavailableView.search
                            .frame(minHeight: 300)
                            .panelCard()
                    } else {
                        KnowledgeGraphView()
                            .panelCard()
                        KnowledgeNodeGridView(
                            nodes: filteredNodes,
                            selectedNodeID: appState.selectedKnowledgeNodeID,
                            score: score,
                            action: select
                        )
                    }
                }
                .frame(maxWidth: 1_280, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
        }
        .searchable(text: $searchText, prompt: "搜索知识点")
        .inspector(isPresented: $isInspectorPresented) {
            if let selectedID = appState.selectedKnowledgeNodeID,
               let node = appState.node(for: selectedID),
               let mastery = appState.mastery(for: selectedID) {
                KnowledgeDetailView(node: node, mastery: mastery)
                    .inspectorColumnWidth(min: 380, ideal: 480, max: 620)
            }
        }
    }

    private func score(for node: KnowledgeNode) -> Double {
        appState.mastery(for: node.id)?.composite ?? 0
    }

    private func select(_ node: KnowledgeNode) {
        appState.selectedKnowledgeNodeID = node.id
        isInspectorPresented = true
    }
}
