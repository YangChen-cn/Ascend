import SwiftUI

struct MenuBarNavigationGrid: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    private struct NavItem: Identifiable {
        let id: String
        let title: String
        let icon: String
        let section: NavigationSection
        let badgeCount: Int
        let badgeColor: Color
        let isReviewAction: Bool

        init(
            id: String,
            title: String,
            icon: String,
            section: NavigationSection,
            badgeCount: Int = 0,
            badgeColor: Color = AscendTheme.amber,
            isReviewAction: Bool = false
        ) {
            self.id = id
            self.title = title
            self.icon = icon
            self.section = section
            self.badgeCount = badgeCount
            self.badgeColor = badgeColor
            self.isReviewAction = isReviewAction
        }
    }

    private var navItems: [NavItem] {
        [
            NavItem(
                id: "today",
                title: "今日",
                icon: "house.fill",
                section: .today
            ),
            NavItem(
                id: "knowledge",
                title: "知识图谱",
                icon: "point.3.connected.trianglepath.dotted",
                section: .knowledge,
                badgeCount: appState.pendingReviewCount,
                badgeColor: AscendTheme.amber
            ),
            NavItem(
                id: "abilities",
                title: "能力地图",
                icon: "map.fill",
                section: .abilities
            ),
            NavItem(
                id: "challenges",
                title: "修炼挑战",
                icon: "flag.checkered",
                section: .challenges,
                badgeCount: appState.challenges.filter { $0.status == "in_progress" }.count,
                badgeColor: AscendTheme.cobalt
            ),
            NavItem(
                id: "evidence",
                title: "资料流",
                icon: "list.bullet.rectangle.portrait.fill",
                section: .evidence,
                badgeCount: appState.pendingActivityCount,
                badgeColor: AscendTheme.amber
            ),
            NavItem(
                id: "review",
                title: "复习",
                icon: "arrow.counterclockwise.circle.fill",
                section: .today,
                badgeCount: appState.forgettingProjections.count,
                badgeColor: AscendTheme.amber,
                isReviewAction: true
            )
        ]
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(navItems) { item in
                Button(action: { navigateTo(item) }) {
                    VStack(spacing: 5) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: item.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(iconColor(for: item))
                                .frame(height: 20)

                            if item.badgeCount > 0 {
                                Text("\(item.badgeCount)")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 3.5)
                                    .padding(.vertical, 1)
                                    .background(item.badgeColor)
                                    .clipShape(Capsule())
                                    .offset(x: 10, y: -4)
                            }
                        }

                        Text(item.title)
                            .font(.system(size: 11, weight: .medium, design: .serif))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(appState.selectedSection == item.section && !item.isReviewAction ? 0.08 : 0.03))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                appState.selectedSection == item.section && !item.isReviewAction
                                    ? AscendTheme.jade.opacity(0.4)
                                    : Color.primary.opacity(0.06),
                                lineWidth: 0.8
                            )
                    }
                }
                .buttonStyle(.plain)
                .help("打开\(item.title)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func iconColor(for item: NavItem) -> Color {
        if item.isReviewAction && item.badgeCount > 0 {
            return AscendTheme.amber
        }
        if item.badgeCount > 0 {
            return item.badgeColor
        }
        return appState.selectedSection == item.section ? AscendTheme.jade : .secondary
    }

    private func navigateTo(_ item: NavItem) {
        if item.isReviewAction {
            if let firstUrgent = appState.forgettingProjections.first {
                appState.selectedKnowledgeNodeID = firstUrgent.node.id
                appState.selectedSection = .knowledge
            } else {
                appState.selectedSection = .today
            }
        } else {
            appState.selectedSection = item.section
        }

        openWindow(id: "main")
        dismiss()
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
