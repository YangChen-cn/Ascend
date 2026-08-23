import SwiftUI

struct AbilityMapView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            FeaturePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AscendTheme.isXuanqing ? "诸天能力 · 领域灵根" : "能力地图")
                                .font(.system(.largeTitle, design: AscendTheme.titleDesign))
                                .bold()
                            Text("领域独立成长，掌握度与知验互不混算，真实见证每一境界的突破。")
                                .font(.system(.callout, design: AscendTheme.titleDesign))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            CelestialBadge(
                                title: "修习领域",
                                subtitle: "\(appState.domainProgress.count)",
                                systemImage: "mountain.2.fill",
                                style: .jade
                            )
                            CelestialBadge(
                                title: "已知知窍",
                                subtitle: "\(appState.knowledgeNodes.count)",
                                systemImage: "point.3.filled.connected.trianglepath.dotted",
                                style: .astral
                            )
                            CelestialBadge(
                                title: "总积知验",
                                subtitle: "\(appState.totalXP.formatted()) XP",
                                systemImage: "flame.fill",
                                style: .gold
                            )
                        }
                    }
                    .panelCard()

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 18)], alignment: .leading, spacing: 18) {
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
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
