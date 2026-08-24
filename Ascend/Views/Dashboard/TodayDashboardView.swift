import SwiftUI

struct TodayDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isReviewSheetPresented = false
    @State private var selectedConstellationDomain: String?
    @State private var showsSuggestionBanner = true

    private var showsGrowthRail: Bool {
        !appState.forgettingProjections.isEmpty
            || !appState.domainProgress.isEmpty
            || !appState.challenges.isEmpty
            || appState.knowledgeNodes.isEmpty
            || appState.sources.isEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
            AppPageScaffold {
                DashboardHeaderView()

                        if appState.pendingReviewCount > 0, showsSuggestionBanner {
                            HStack {
                                Image(systemName: "sparkle.magnifyingglass")
                                    .foregroundStyle(AscendTheme.gold)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(appState.pendingReviewCount) 条知识归属建议可确认")
                                        .font(.headline)
                                    Text("审核只确认知识归属，不影响日常成长；有空时处理即可")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("立即审核", systemImage: "checkmark.seal") {
                                    isReviewSheetPresented = true
                                }
                                .buttonStyle(.bordered)
                                Button {
                                    withAnimation { showsSuggestionBanner = false }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("暂不提醒")
                                .help("暂不提醒")
                            }
                            .padding(14)
                            .background(AscendTheme.gold.opacity(0.08))
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(AscendTheme.gold.opacity(0.25), lineWidth: 1)
                            }
                            .transition(.opacity)
                        }

                if showsGrowthRail {
                    AdaptivePageColumns {
                        mainColumn
                    } supplementary: {
                        GrowthRailView()
                    }

                    EvidenceTimelineView()
                        .sectionSurface(.grouped)
                } else {
                    mainColumn
                    EvidenceTimelineView()
                        .sectionSurface(.grouped)
                }
            }
            .id("dashboard-top")
            .onAppear {
                proxy.scrollTo("dashboard-top", anchor: .top)
            }
            .overlay(alignment: .bottomLeading) {
                if let message = appState.presentedStatusMessage {
                    HStack(spacing: 10) {
                        Label(message, systemImage: "info.circle")
                            .lineLimit(3)

                        if appState.analysisProgressMessage == nil {
                            Button("关闭提示", systemImage: "xmark", action: appState.dismissStatusMessage)
                                .labelStyle(.iconOnly)
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .help("关闭提示")
                        }
                    }
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 8))
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: appState.presentedStatusMessage)
            .sheet(isPresented: $isReviewSheetPresented) {
                TaxonomyReviewSheet()
            }
        }
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: AscendTheme.Spacing.section) {
            GrowthOverviewView()
                .sectionSurface(.grouped)
            DashboardConstellationGalleryView(
                selectedDomainName: $selectedConstellationDomain,
                openKnowledgeNode: openKnowledgeNode
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openKnowledgeNode(_ node: KnowledgeNode) {
        appState.selectedKnowledgeNodeID = node.id
        appState.selectedSection = .knowledge
    }
}
