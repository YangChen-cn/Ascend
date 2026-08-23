import SwiftUI

struct AbilityMapView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            FeaturePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeaderView("能力地图", systemImage: "map")

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        MetricTileView(
                            title: "修习领域",
                            value: appState.domainProgress.count.formatted(),
                            systemImage: "square.grid.2x2",
                            detail: "每个领域独立成长"
                        )
                        MetricTileView(
                            title: "知识点",
                            value: appState.knowledgeNodes.count.formatted(),
                            systemImage: "point.3.connected.trianglepath.dotted",
                            detail: "均可追溯到学习证据"
                        )
                        MetricTileView(
                            title: "终身知验",
                            value: "\(appState.totalXP.formatted()) XP",
                            systemImage: "seal",
                            detail: "跨领域累计且不会回退"
                        )
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], alignment: .leading, spacing: 16) {
                        if appState.domainProgress.isEmpty {
                            AbilityEmptyStateView()
                        } else {
                            ForEach(appState.domainProgress) { domain in
                                DomainProgressCardView(domain: domain)
                            }
                        }
                        RealmLadderView()
                    }
                }
                .frame(maxWidth: 1_280, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
