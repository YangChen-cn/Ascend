import SwiftUI

struct TodayDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var isReviewSheetPresented = false
    @State private var selectedConstellationDomain: String?

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                FeaturePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        DashboardHeaderView()
                            .panelCard()

                        if appState.pendingReviewCount > 0 {
                            HStack {
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .foregroundStyle(AscendTheme.amber)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("有 \(appState.pendingReviewCount) 条知识点与证据建议待确认")
                                        .font(.headline)
                                    Text("审核只确认知识归属；主动验证后才会更新掌握与 XP")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("立即审核", systemImage: "checkmark.seal") {
                                    isReviewSheetPresented = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AscendTheme.amber)
                            }
                            .padding(14)
                            .background(AscendTheme.amber.opacity(0.10))
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AscendTheme.amber.opacity(0.30), lineWidth: 1)
                            }
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 18) {
                                mainColumn
                                GrowthRailView()
                                    .frame(width: 300)
                            }

                            VStack(alignment: .leading, spacing: 18) {
                                mainColumn
                                GrowthRailView()
                            }
                        }
                    }
                    .id("dashboard-top")
                    .frame(maxWidth: 1_320, alignment: .leading)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
            }
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
            .animation(.easeOut(duration: 0.2), value: appState.presentedStatusMessage)
            .sheet(isPresented: $isReviewSheetPresented) {
                TaxonomyReviewSheet()
            }
        }
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            GrowthOverviewView()
                .panelCard()
            DashboardConstellationGalleryView(
                selectedDomainName: $selectedConstellationDomain,
                openKnowledgeNode: openKnowledgeNode
            )
            EvidenceTimelineView()
                .panelCard()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openKnowledgeNode(_ node: KnowledgeNode) {
        appState.selectedKnowledgeNodeID = node.id
        appState.selectedSection = .knowledge
    }
}
