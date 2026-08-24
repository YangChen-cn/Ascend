import SwiftUI

struct DashboardConstellationGalleryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedDomainName: String?

    let openKnowledgeNode: (KnowledgeNode) -> Void

    private var selectedDomain: DomainProgressSnapshot? {
        appState.domainProgress.first { $0.name == selectedDomainName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("诸域周天", systemImage: "sparkles.rectangle.stack")
                            .font(.system(.headline, design: .serif))
                            .bold()
                        Text("点击领域切换星图，各域掌握、知验与境界独立计算。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("查看全部星图", systemImage: "square.grid.2x2", action: showAllConstellations)
                        .buttonStyle(.bordered)
                }

                if appState.domainProgress.isEmpty {
                    ContentUnavailableView(
                        "尚无领域",
                        systemImage: "sparkles.rectangle.stack",
                        description: Text("完成学习分析并确认知识点后，各领域会在这里形成独立星图。")
                    )
                    .frame(minHeight: 120)
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 12) {
                            ForEach(appState.domainProgress) { domain in
                                DomainConstellationCard(
                                    domain: domain,
                                    isSelected: domain.name == selectedDomainName,
                                    select: { select(domain) }
                                )
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                }
            }
            .sectionSurface(.grouped)

            if let selectedDomain {
                KnowledgeGraphView(
                    domainName: selectedDomain.name,
                    nodes: appState.nodes(inDomain: selectedDomain.name),
                    score: score,
                    action: openKnowledgeNode
                )
                .id(selectedDomain.id)
                .sectionSurface(.emphasized)
            } else {
                KnowledgeGraphView(
                    domainName: "周天",
                    nodes: [],
                    score: { _ in 0 },
                    action: { _ in }
                )
                .sectionSurface(.emphasized)
            }
        }
        .onAppear(perform: repairSelection)
        .onChange(of: appState.domainNames) { _, _ in
            repairSelection()
        }
    }

    private func select(_ domain: DomainProgressSnapshot) {
        withAnimation(reduceMotion ? nil : .snappy) {
            selectedDomainName = domain.name
        }
    }

    private func repairSelection() {
        guard appState.domainNames.contains(selectedDomainName ?? "") else {
            selectedDomainName = appState.domainNames.first
            return
        }
    }

    private func score(for node: KnowledgeNode) -> Double {
        appState.readiness(for: node.id)?.currentComposite ?? 0
    }

    private func showAllConstellations() {
        appState.selectedSection = .knowledge
    }
}
