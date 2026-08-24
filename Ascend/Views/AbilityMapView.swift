import SwiftUI

struct AbilityMapView: View {
    @Environment(AppState.self) private var appState
    @State private var domainManagementContext: DomainManagementContext?

    var body: some View {
        AppPageScaffold {
            ResponsivePageHeader {
                PageHeaderView(
                    AscendTheme.isXuanqing ? "诸天能力 · 领域灵根" : "能力地图",
                    subtitle: "领域独立成长，掌握度与知验互不混算，真实见证每一境界的突破。",
                    systemImage: "mountain.2.fill"
                )

            } actions: {
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
                        style: .jade
                    )
                    CelestialBadge(
                        title: "总积知验",
                        subtitle: "\(appState.totalXP.formatted()) XP",
                        systemImage: "flame.fill",
                        style: .gold
                    )
                    Button("管理领域", systemImage: "folder.badge.gearshape") {
                        domainManagementContext = DomainManagementContext(initialDomain: appState.domainNames.first)
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            }

            AdaptivePageColumns {
                VStack(alignment: .leading, spacing: AscendTheme.Spacing.section) {
                    if appState.domainProgress.isEmpty {
                        AbilityEmptyStateView()
                            .sectionSurface(.grouped)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(appState.domainProgress) { domain in
                                DomainProgressCardView(domain: domain) {
                                    domainManagementContext = DomainManagementContext(initialDomain: domain.name)
                                }
                            }
                        }

                        // 当领域较少（<= 2）时，展示六境全景卡，充实修行画卷
                        if appState.domainProgress.count <= 2 {
                            RealmPanoramaOverviewCard()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } supplementary: {
                RealmLadderView()
                    .sectionSurface(.grouped)
            }
        }
        .sheet(item: $domainManagementContext) { context in
            DomainManagementSheet(initialDomain: context.initialDomain)
        }
    }
}
