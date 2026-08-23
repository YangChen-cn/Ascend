import SwiftUI

struct TodayDashboardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                FeaturePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        DashboardHeaderView()
                            .panelCard()

                        HStack(alignment: .top, spacing: 18) {
                            VStack(alignment: .leading, spacing: 18) {
                                GrowthOverviewView()
                                    .panelCard()
                                KnowledgeGraphView()
                                    .panelCard()
                                EvidenceTimelineView()
                                    .panelCard()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            GrowthRailView()
                                .frame(width: 310)
                                .panelCard()
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
                if let message = appState.statusMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 8))
                        .padding()
                }
            }
        }
    }
}
