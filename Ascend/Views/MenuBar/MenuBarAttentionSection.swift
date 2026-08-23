import SwiftUI

struct MenuBarAttentionSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Binding var isReviewSheetPresented: Bool

    private var urgentForgetting: ForgettingProjection? {
        appState.forgettingProjections.first
    }

    private var pendingTaxonomyCount: Int {
        appState.pendingReviewCount
    }

    private var activeChallenge: Challenge? {
        appState.challenges.first(where: { $0.status == "in_progress" })
    }

    private var topGrowth: DashboardMetric? {
        appState.todayMasteryChanges.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let urgent = urgentForgetting {
                // MARK: - 优先级 1：到期复习 / 急需温故
                attentionCard(
                    icon: "arrow.counterclockwise",
                    iconColor: AscendTheme.amber,
                    tag: "急需温故",
                    tagColor: AscendTheme.amber,
                    title: urgent.node.name,
                    subtitle: "衰减 -\(urgent.scoreLoss) 分 · 记忆留存率 \(Int(urgent.retention))%",
                    actionTitle: "立即温故",
                    action: { openNode(urgent.node) }
                )
            } else if pendingTaxonomyCount > 0 {
                // MARK: - 优先级 2：待定真意
                let topSuggestion = appState.taxonomySuggestions.first(where: { $0.status == "pending" })
                attentionCard(
                    icon: "exclamationmark.circle.fill",
                    iconColor: AscendTheme.amber,
                    tag: "待定真意",
                    tagColor: AscendTheme.amber,
                    title: topSuggestion?.proposedName ?? "\(pendingTaxonomyCount) 条证据建议",
                    subtitle: "审核后正式收录入知识图谱与五维评分",
                    actionTitle: "立即审核",
                    action: { isReviewSheetPresented = true }
                )
            } else if let challenge = activeChallenge {
                // MARK: - 优先级 3：进行中挑战
                attentionCard(
                    icon: "flag.checkered",
                    iconColor: AscendTheme.cobalt,
                    tag: "研习挑战",
                    tagColor: AscendTheme.cobalt,
                    title: challenge.title,
                    subtitle: "奖励 \(challenge.rewardXP) XP · \(challenge.challengeDescription.prefix(24))",
                    actionTitle: "查看挑战",
                    action: {
                        appState.selectedSection = .challenges
                        openMainWindow()
                    }
                )
            } else if let growth = topGrowth {
                // MARK: - 优先级 4：今日精进
                attentionCard(
                    icon: "sparkles",
                    iconColor: AscendTheme.gold,
                    tag: "今日精进",
                    tagColor: AscendTheme.gold,
                    title: growth.title,
                    subtitle: "掌握度提升 \(growth.previous) → \(growth.current) 分",
                    actionTitle: "今日看板",
                    action: {
                        appState.selectedSection = .today
                        openMainWindow()
                    }
                )
            } else {
                // MARK: - 保底状态：灵台清明
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(AscendTheme.jade)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("灵台清明 · 道基稳固")
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                        Text("当前所悟知识暂无遗忘之虞，道法精进自然。")
                            .font(.system(size: 10, design: .serif))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AscendTheme.jade.opacity(0.05))
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func attentionCard(
        icon: String,
        iconColor: Color,
        tag: String,
        tagColor: Color,
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(tagColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tag)
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .foregroundStyle(tagColor)

                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .lineLimit(1)
                }

                Text(subtitle)
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(tagColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tagColor.opacity(0.10))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tagColor.opacity(0.20), lineWidth: 0.8)
        }
    }

    private func openNode(_ node: KnowledgeNode) {
        appState.selectedKnowledgeNodeID = node.id
        appState.selectedSection = .knowledge
        openMainWindow()
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
