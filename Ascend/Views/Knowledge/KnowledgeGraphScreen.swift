import SwiftUI

struct KnowledgeGraphScreen: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var isInspectorPresented = false
    @State private var domainManagementContext: DomainManagementContext?

    private var filteredNodes: [KnowledgeNode] {
        guard !searchText.isEmpty else { return appState.knowledgeNodes }
        return appState.knowledgeNodes.filter {
            $0.name.localizedStandardContains(searchText) || $0.domain.localizedStandardContains(searchText)
        }
    }

    private var domainGroups: [KnowledgeDomainGroup] {
        let grouped = Dictionary(grouping: filteredNodes, by: \.domain)
        let order = Dictionary(uniqueKeysWithValues: appState.domainNames.enumerated().map { ($1, $0) })
        return grouped.map { KnowledgeDomainGroup(name: $0.key, nodes: $0.value) }
            .sorted {
                let lhsOrder = order[$0.name] ?? .max
                let rhsOrder = order[$1.name] ?? .max
                return lhsOrder == rhsOrder
                    ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    : lhsOrder < rhsOrder
            }
    }

    var body: some View {
        ZStack {
            FeaturePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center) {
                        PageHeaderView(
                            "知识图谱",
                            subtitle: "一域一图，循各领域独立知脉观其掌握与关联。",
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                        Spacer()
                        Button("管理领域", systemImage: "folder.badge.gearshape") {
                            domainManagementContext = DomainManagementContext(initialDomain: appState.domainNames.first)
                        }
                        .buttonStyle(.bordered)
                    }

                    if appState.knowledgeNodes.isEmpty {
                        KnowledgeGraphEmptyStateView()
                    } else if filteredNodes.isEmpty {
                        ContentUnavailableView.search
                            .frame(minHeight: 300)
                            .panelCard()
                    } else {
                        ForEach(domainGroups) { group in
                            KnowledgeDomainSectionView(
                                group: group,
                                selectedNodeID: appState.selectedKnowledgeNodeID,
                                score: score,
                                selectNode: select,
                                manageDomain: {
                                    domainManagementContext = DomainManagementContext(initialDomain: group.name)
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: 1_280, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
        }
        .searchable(text: $searchText, prompt: "搜索知识点")
        .sheet(item: $domainManagementContext) { context in
            DomainManagementSheet(initialDomain: context.initialDomain)
        }
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
        appState.readiness(for: node.id)?.currentComposite ?? 0
    }

    private func select(_ node: KnowledgeNode) {
        appState.selectedKnowledgeNodeID = node.id
        isInspectorPresented = true
    }
}
