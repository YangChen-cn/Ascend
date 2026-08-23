import SwiftUI

struct MenuBarAttentionSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Binding var isReviewSheetPresented: Bool

    private var attentionItems: [MenuBarAttentionItem] {
        var items: [MenuBarAttentionItem] = []

        for plan in appState.reviewPlans where plan.status == "due" {
            let name = appState.node(for: plan.knowledgeNodeID)?.name ?? "待复习知识"
            items.append(
                MenuBarAttentionItem(
                    id: "review-\(plan.id.uuidString)",
                    priority: 0,
                    icon: "arrow.counterclockwise",
                    tint: AscendTheme.amber,
                    title: name,
                    status: "今日到期",
                    destination: .knowledge(plan.knowledgeNodeID)
                )
            )
        }

        for suggestion in appState.taxonomySuggestions where suggestion.status == "pending" {
            items.append(
                MenuBarAttentionItem(
                    id: "suggestion-\(suggestion.id.uuidString)",
                    priority: 1,
                    icon: "exclamationmark",
                    tint: AscendTheme.amber,
                    title: suggestion.proposedName,
                    status: "待确认",
                    destination: .taxonomyReview
                )
            )
        }

        for challenge in appState.challenges where challenge.status == "in_progress" {
            guard let progress = challengeProgress(challenge),
                  progress.matched > 0,
                  progress.matched < progress.required,
                  Double(progress.matched) / Double(progress.required) >= 0.5 else { continue }
            items.append(
                MenuBarAttentionItem(
                    id: "challenge-\(challenge.id.uuidString)",
                    priority: 2,
                    icon: "flag.checkered",
                    tint: AscendTheme.cobalt,
                    title: challenge.title,
                    status: "\(progress.matched) / \(progress.required)",
                    destination: .challenges
                )
            )
        }

        for projection in appState.forgettingProjections where projection.retention < 60 {
            items.append(
                MenuBarAttentionItem(
                    id: "forgetting-\(projection.node.id.uuidString)",
                    priority: 3,
                    icon: "hourglass.bottomhalf.filled",
                    tint: AscendTheme.amber,
                    title: projection.node.name,
                    status: "留存 \(Int(projection.retention.rounded()))%",
                    destination: .knowledge(projection.node.id)
                )
            )
        }

        for growth in appState.todayMasteryChanges where growth.current > growth.previous {
            items.append(
                MenuBarAttentionItem(
                    id: "growth-\(growth.id.uuidString)",
                    priority: 4,
                    icon: "sparkles",
                    tint: AscendTheme.jade,
                    title: growth.title,
                    status: "+\(growth.current - growth.previous) 掌握",
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
        let visibleItems = items.prefix(3)

        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("待办与提醒")
                    .font(.system(.caption, design: .serif))
                    .bold()

                Spacer()

                if !items.isEmpty {
                    Text("\(items.count) 项")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 2)

            if visibleItems.isEmpty {
                Label("暂无急务，采集与研习状态平稳", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 5)
            } else {
                ForEach(visibleItems) { item in
                    Button(action: { open(item.destination) }) {
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.caption)
                                .foregroundStyle(item.tint)
                                .frame(width: 14)

                            Text(item.title)
                                .font(.system(.caption, design: .serif))
                                .lineLimit(1)

                            Spacer(minLength: 6)

                            Text(item.status)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.title)，\(item.status)")
                }

                if items.count > visibleItems.count {
                    Button(action: openToday) {
                        HStack {
                            Spacer()
                            Text("还有 \(items.count - visibleItems.count) 项")
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption)
                        .foregroundStyle(AscendTheme.amber)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
            openToday()
        }
    }

    private func openToday() {
        appState.selectedSection = .today
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
