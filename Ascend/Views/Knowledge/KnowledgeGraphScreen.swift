import SwiftUI

struct KnowledgeGraphScreen: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var isInspectorPresented = false
    @State private var domainManagementContext: DomainManagementContext?

    private var filteredDomains: [ConstellationDomainRenderSnapshot] {
        let domains = appState.knowledgeGraphRenderSnapshot.domains
        guard !searchText.isEmpty else { return domains }
        return domains.compactMap { $0.filteringNodes(matching: searchText) }
    }

    var body: some View {
        AppPageScaffold {
                    ResponsivePageHeader {
                        PageHeaderView(
                            "知识图谱",
                            subtitle: "一域一图，循各领域独立知脉观其掌握与关联。",
                            systemImage: "point.3.connected.trianglepath.dotted"
                        )
                    } actions: {
                        Button("管理领域", systemImage: "folder.badge.gearshape") {
                            domainManagementContext = DomainManagementContext(initialDomain: appState.domainNames.first)
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }

                    if appState.knowledgeGraphRenderSnapshot.nodeCount == 0 {
                        KnowledgeGraphEmptyStateView()
                    } else if filteredDomains.isEmpty {
                        ContentUnavailableView.search
                            .padding(.vertical, 44)
                            .sectionSurface(.grouped)
                    } else {
                        ForEach(filteredDomains) { domain in
                            KnowledgeDomainSectionView(
                                snapshot: domain,
                                selectedNodeID: appState.selectedKnowledgeNodeID,
                                selectNode: select,
                                openNode: open,
                                persistPosition: { nodeID, position in
                                    appState.constellationLayoutStore.save(
                                        position: position,
                                        nodeID: nodeID,
                                        domainName: domain.name
                                    )
                                },
                                resetPersistedLayout: {
                                    appState.constellationLayoutStore.reset(domainName: domain.name)
                                },
                                manageDomain: {
                                    domainManagementContext = DomainManagementContext(initialDomain: domain.name)
                                }
                            )
                        }
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
                KnowledgeDetailView(
                    node: node,
                    mastery: mastery,
                    readinessSnapshot: appState.knowledgeGraphRenderSnapshot.node(id: selectedID)?.readiness,
                    onClose: {
                        if isInspectorPresented { isInspectorPresented = false }
                    }
                )
                .inspectorColumnWidth(min: 360, ideal: 420, max: 540)
            }
        }
        .onKeyPress(.escape) {
            if appState.selectedKnowledgeNodeID != nil {
                appState.selectedKnowledgeNodeID = nil
                return .handled
            }
            return .ignored
        }
    }

    private func select(_ nodeID: UUID?) {
        guard let nodeID else {
            if appState.selectedKnowledgeNodeID != nil {
                appState.selectedKnowledgeNodeID = nil
            }
            return
        }
        if appState.selectedKnowledgeNodeID == nodeID {
            appState.selectedKnowledgeNodeID = nil
        } else {
            appState.selectedKnowledgeNodeID = nodeID
        }
    }

    private func open(_ nodeID: UUID) {
        if appState.selectedKnowledgeNodeID != nodeID {
            appState.selectedKnowledgeNodeID = nodeID
        }
        if !isInspectorPresented { isInspectorPresented = true }
    }
}
