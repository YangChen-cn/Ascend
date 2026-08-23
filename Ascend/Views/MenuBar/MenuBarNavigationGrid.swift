import SwiftUI

struct MenuBarNavigationGrid: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Binding var isReviewSheetPresented: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    private var activeChallenges: [Challenge] {
        appState.challenges.filter { $0.status == "in_progress" }
    }

    private var pendingSuggestionsCount: Int {
        appState.taxonomySuggestions.count { $0.status == "pending" }
    }

    private var primaryDomainSummary: (realm: String, score: String)? {
        guard let domain = appState.domainProgress.first(where: { $0.xp > 0 || $0.currentScore > 0 })
                ?? appState.domainProgress.first else {
            return nil
        }
        return (domain.currentRealm.title, "\(Int(domain.currentScore.rounded()))")
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            // 第一行：知识 / 能力 / 挑战
            StatsCell(
                number: "\(appState.knowledgeNodes.count)",
                title: "知识",
                help: "查看全部 \(appState.knowledgeNodes.count) 个知识点"
            ) {
                navigateTo(.knowledge)
            }

            StatsCell(
                number: primaryDomainSummary.map { "\($0.realm)·\($0.score)" } ?? "尚未入境",
                title: primaryDomainSummary == nil ? "能力" : "",
                help: "查看能力地图"
            ) {
                navigateTo(.abilities)
            }

            StatsCell(
                number: "\(activeChallenges.count)",
                title: "挑战",
                help: "查看 \(activeChallenges.count) 个进行中挑战"
            ) {
                navigateTo(.challenges)
            }

            // 第二行：资料流 / 复习 / 待确认
            StatsCell(
                number: "\(appState.pendingActivityCount)",
                title: "待析",
                help: "查看资料流与 \(appState.pendingActivityCount) 条待分析活动"
            ) {
                navigateTo(.evidence)
            }

            StatsCell(
                number: "\(appState.dueReviewCount)",
                title: "到期",
                help: "查看 \(appState.dueReviewCount) 个到期复习知识点"
            ) {
                handleReview()
            }

            StatsCell(
                number: "\(pendingSuggestionsCount)",
                title: "待确认",
                help: "审阅 \(pendingSuggestionsCount) 个待确认知识建议"
            ) {
                handleTaxonomyReview()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func navigateTo(_ section: NavigationSection) {
        appState.selectedSection = section
        openMainWindow()
    }

    private func handleReview() {
        if let duePlan = appState.reviewPlans.first(where: { $0.status == "due" }) {
            appState.selectedKnowledgeNodeID = duePlan.knowledgeNodeID
            appState.selectedSection = .knowledge
        } else if let firstUrgent = appState.forgettingProjections.first {
            appState.selectedKnowledgeNodeID = firstUrgent.node.id
            appState.selectedSection = .knowledge
        } else {
            appState.selectedSection = .today
        }
        openMainWindow()
    }

    private func handleTaxonomyReview() {
        if pendingSuggestionsCount > 0 {
            isReviewSheetPresented = true
        } else {
            appState.selectedSection = .today
            openMainWindow()
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        dismiss()
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - 紧凑统计单格

private struct StatsCell: View {
    let number: String
    let title: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(number)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}
