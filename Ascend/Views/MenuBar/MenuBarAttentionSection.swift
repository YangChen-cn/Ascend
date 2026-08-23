import SwiftUI

struct MenuBarAttentionSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isReviewSheetPresented: Bool

    @State private var hoveredItemID: String?

    private var attentionItems: [MenuBarAttentionItem] {
        var items: [MenuBarAttentionItem] = []

        // 1. 到期复习
        for plan in appState.reviewPlans where plan.status == "due" {
            let name = appState.node(for: plan.knowledgeNodeID)?.name ?? "待复习知识"
            let retention = appState.forgettingProjections.first(where: { $0.node.id == plan.knowledgeNodeID })?.retention
            let statusText = retention.map { "留存 \(Int($0.rounded()))%" } ?? "今日到期"
            items.append(
                MenuBarAttentionItem(
                    id: "review-\(plan.id.uuidString)",
                    priority: 0,
                    icon: "arrow.counterclockwise",
                    tint: (retention ?? 100) < 30
                        ? MenuBarPalette.cinnabar(colorScheme)
                        : MenuBarPalette.gold(colorScheme),
                    title: name,
                    status: statusText,
                    destination: .knowledge(plan.knowledgeNodeID)
                )
            )
        }

        // 2. 严重遗忘 (留存 < 60% 且尚未列入复习)
        let dueNodeIDs = Set(appState.reviewPlans.filter { $0.status == "due" }.map(\.knowledgeNodeID))
        for projection in appState.forgettingProjections where projection.retention < 60 && !dueNodeIDs.contains(projection.node.id) {
            items.append(
                MenuBarAttentionItem(
                    id: "forgetting-\(projection.node.id.uuidString)",
                    priority: 1,
                    icon: "hourglass",
                    tint: projection.retention < 30
                        ? MenuBarPalette.cinnabar(colorScheme)
                        : MenuBarPalette.gold(colorScheme),
                    title: projection.node.name,
                    status: "留存 \(Int(projection.retention.rounded()))%",
                    destination: .knowledge(projection.node.id)
                )
            )
        }

        // 3. 待确认建议
        for suggestion in appState.taxonomySuggestions where suggestion.status == "pending" {
            items.append(
                MenuBarAttentionItem(
                    id: "suggestion-\(suggestion.id.uuidString)",
                    priority: 2,
                    icon: "exclamationmark",
                    tint: MenuBarPalette.cinnabar(colorScheme),
                    title: suggestion.proposedName,
                    status: "待确认",
                    destination: .taxonomyReview
                )
            )
        }

        // 4. 接近完成挑战
        for challenge in appState.challenges where challenge.status == "in_progress" {
            guard let progress = challengeProgress(challenge),
                  progress.matched > 0,
                  progress.matched < progress.required,
                  Double(progress.matched) / Double(progress.required) >= 0.5 else { continue }
            items.append(
                MenuBarAttentionItem(
                    id: "challenge-\(challenge.id.uuidString)",
                    priority: 3,
                    icon: "flag.checkered",
                    tint: MenuBarPalette.gold(colorScheme),
                    title: challenge.title,
                    status: "\(progress.matched) / \(progress.required)",
                    destination: .challenges
                )
            )
        }

        // 5. 采集同步失败
        for source in appState.sources where source.isEnabled && source.lastSyncError != nil {
            items.append(
                MenuBarAttentionItem(
                    id: "source-err-\(source.id.uuidString)",
                    priority: 4,
                    icon: "exclamationmark.triangle.fill",
                    tint: MenuBarPalette.cinnabar(colorScheme),
                    title: source.name,
                    status: "同步失败",
                    destination: .today
                )
            )
        }

        return items.sorted {
            $0.priority == $1.priority
                ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                : $0.priority < $1.priority
        }
    }

    var body: some View {
        let items = attentionItems
        let visibleItems = Array(items.prefix(3))

        if !visibleItems.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("待温故")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(MenuBarPalette.ink(colorScheme))

                    Spacer()

                    Text("\(items.count) 项")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                }
                .padding(.horizontal, 2)

                VStack(spacing: 2) {
                    ForEach(visibleItems) { item in
                        Button(action: { open(item.destination) }) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(item.tint)
                                    .frame(width: 2.5, height: 27)

                                Text(item.title)
                                    .font(.system(size: 12))
                                    .foregroundStyle(MenuBarPalette.ink(colorScheme))
                                    .lineLimit(1)

                                Spacer(minLength: 8)

                                Text(item.status)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                                    .lineLimit(1)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme).opacity(0.55))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(hoveredItemID == item.id ? MenuBarPalette.hoverFill(colorScheme) : Color.clear)
                            )
                            .contentShape(.rect)
                        }
                        .buttonStyle(MenuBarPressButtonStyle())
                        .onHover { hovering in
                            hoveredItemID = hovering ? item.id : nil
                        }
                        .accessibilityLabel("\(item.title)，\(item.status)")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func challengeProgress(_ challenge: Challenge) -> (matched: Int, required: Int)? {
        guard let automation = appState.challengeAutomationStates.first(where: { $0.challengeID == challenge.id }) else {
            return nil
        }
        return (
            Set(automation.matchedEvidenceIDs).count,
            max(automation.requirement.requiredEvidenceCount, challenge.knowledgeNodeIDs.count)
        )
    }

    private func open(_ destination: MenuBarAttentionItem.Destination) {
        switch destination {
        case let .knowledge(nodeID):
            appState.selectedKnowledgeNodeID = nodeID
            appState.selectedSection = .knowledge
            openMainWindow()
        case .taxonomyReview:
            isReviewSheetPresented = true
        case .challenges:
            appState.selectedSection = .challenges
            openMainWindow()
        case .today:
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
