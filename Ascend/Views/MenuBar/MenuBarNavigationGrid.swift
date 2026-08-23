import SwiftUI

struct MenuBarNavigationGrid: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    private var todayXP: Int {
        appState.todayXPGains.reduce(0) { $0 + $1.xp }
    }

    private var todayKnowledgeCount: Int {
        appState.knowledgeNodes.count {
            !$0.isProvisional && Calendar.current.isDateInToday($0.createdAt)
        }
    }

    private var todayMasteryGain: Int {
        appState.todayMasteryChanges.reduce(0) { result, metric in
            result + max(0, metric.current - metric.previous)
        }
    }

    private var activeChallenges: [Challenge] {
        appState.challenges.filter { $0.status == "in_progress" }
    }

    private var nearCompletionChallengeCount: Int {
        activeChallenges.count { challenge in
            guard let automation = appState.challengeAutomationStates.first(where: { $0.challengeID == challenge.id }) else {
                return false
            }
            let target = max(automation.requirement.requiredEvidenceCount, challenge.knowledgeNodeIDs.count)
            let matched = Set(automation.matchedEvidenceIDs).count
            return target > 0 && matched > 0 && matched < target && Double(matched) / Double(target) >= 0.5
        }
    }

    private var navItems: [MenuBarNavigationItem] {
        let primaryDomain = appState.domainProgress.first
        return [
            MenuBarNavigationItem(
                id: "today",
                title: "今日",
                icon: "sun.max.fill",
                section: .today,
                primaryMetric: "+\(todayXP) XP",
                secondaryMetric: "\(appState.todayActivityCount) 条活动",
                tint: AscendTheme.gold,
                isReviewAction: false
            ),
            MenuBarNavigationItem(
                id: "knowledge",
                title: "知识",
                icon: "point.3.connected.trianglepath.dotted",
                section: .knowledge,
                primaryMetric: "\(appState.knowledgeNodes.count) 知识点",
                secondaryMetric: "今日 +\(todayKnowledgeCount)",
                tint: AscendTheme.jade,
                isReviewAction: false
            ),
            MenuBarNavigationItem(
                id: "abilities",
                title: "能力",
                icon: "map.fill",
                section: .abilities,
                primaryMetric: primaryDomain.map { "\($0.currentRealm.title) · \(Int($0.currentScore.rounded()))" } ?? "尚未入境",
                secondaryMetric: "今日 +\(todayMasteryGain)",
                tint: AscendTheme.jade,
                isReviewAction: false
            ),
            MenuBarNavigationItem(
                id: "challenges",
                title: "挑战",
                icon: "flag.checkered",
                section: .challenges,
                primaryMetric: "\(activeChallenges.count) 进行中",
                secondaryMetric: "\(nearCompletionChallengeCount) 接近完成",
                tint: activeChallenges.isEmpty ? AscendTheme.cobalt : AscendTheme.amber,
                isReviewAction: false
            ),
            MenuBarNavigationItem(
                id: "evidence",
                title: "资料流",
                icon: "list.bullet.rectangle.portrait.fill",
                section: .evidence,
                primaryMetric: "\(appState.pendingActivityCount) 待分析",
                secondaryMetric: "今日采集 \(appState.todayActivityCount)",
                tint: appState.pendingActivityCount > 0 ? AscendTheme.amber : AscendTheme.jade,
                isReviewAction: false
            ),
            MenuBarNavigationItem(
                id: "review",
                title: "复习",
                icon: "arrow.counterclockwise.circle.fill",
                section: .today,
                primaryMetric: "\(appState.dueReviewCount) 到期",
                secondaryMetric: "\(appState.forgettingProjections.count) 久疏",
                tint: appState.dueReviewCount > 0 ? AscendTheme.amber : AscendTheme.jade,
                isReviewAction: true
            )
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(navItems) { item in
                Button(action: { navigateTo(item) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(.caption)
                                .foregroundStyle(item.tint)
                                .frame(width: 15)

                            Text(item.title)
                                .font(.system(.caption, design: .serif))
                                .bold()
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)
                        }

                        Text(item.primaryMetric)
                            .font(.subheadline.monospacedDigit())
                            .bold()
                            .foregroundStyle(item.tint)
                            .lineLimit(1)

                        Text(item.secondaryMetric)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.primary.opacity(isSelected(item) ? 0.075 : 0.025))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                isSelected(item) ? item.tint.opacity(0.35) : Color.primary.opacity(0.055),
                                lineWidth: 0.8
                            )
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("打开\(item.title)")
                .accessibilityLabel("\(item.title)，\(item.primaryMetric)，\(item.secondaryMetric)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func isSelected(_ item: MenuBarNavigationItem) -> Bool {
        !item.isReviewAction && appState.selectedSection == item.section
    }

    private func navigateTo(_ item: MenuBarNavigationItem) {
        if item.isReviewAction {
            if let duePlan = appState.reviewPlans.first(where: { $0.status == "due" }) {
                appState.selectedKnowledgeNodeID = duePlan.knowledgeNodeID
                appState.selectedSection = .knowledge
            } else if let firstUrgent = appState.forgettingProjections.first {
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
