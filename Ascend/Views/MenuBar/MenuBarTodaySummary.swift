import SwiftUI

struct MenuBarTodaySummary: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var hoveredItemID: String?

    private var todayXP: Int {
        appState.todayXPGains.reduce(0) { $0 + $1.xp }
    }

    private var learningItems: [TodayLearningItem] {
        let calendar = Calendar.current
        let todayEvidence = appState.evidenceRecords.filter {
            $0.isVerified && calendar.isDateInToday($0.timestamp)
        }
        let todayLedger = appState.scoreLedgerEntries.filter {
            calendar.isDateInToday($0.timestamp)
        }
        let todayNodes = appState.knowledgeNodes.filter {
            !$0.isProvisional && calendar.isDateInToday($0.createdAt)
        }

        var nodeIDs = Set<UUID>()
        for e in todayEvidence { nodeIDs.insert(e.knowledgeNodeID) }
        for l in todayLedger { nodeIDs.insert(l.knowledgeNodeID) }
        for n in todayNodes { nodeIDs.insert(n.id) }

        let masteryChangesByTitle = Dictionary(
            appState.todayMasteryChanges.map { ($0.title, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var xpByNode: [UUID: Int] = [:]
        for l in todayLedger {
            xpByNode[l.knowledgeNodeID, default: 0] += l.xpAwarded
        }

        var items: [TodayLearningItem] = []

        for nodeID in nodeIDs {
            guard let node = appState.node(for: nodeID) else { continue }
            let isNew = todayNodes.contains { $0.id == nodeID }
            let xp = xpByNode[nodeID, default: 0]
            let mastery = masteryChangesByTitle[node.name]
            let masteryDelta = (mastery?.current ?? 0) - (mastery?.previous ?? 0)
            let domain = node.domain.trimmingCharacters(in: .whitespacesAndNewlines)

            let nodeEvidence = todayEvidence.filter { $0.knowledgeNodeID == nodeID }
            let practicalKinds: Set<EvidenceKind> = [.exercise, .project, .independentSolve]
            let hasPractice = nodeEvidence.contains { practicalKinds.contains($0.kind) }
            let hasExplanation = nodeEvidence.contains { $0.kind == .explanation }

            let subtitle: String
            let priority: Int

            if isNew {
                priority = 100 + xp
                if !domain.isEmpty {
                    subtitle = "新增知识 · \(domain)"
                } else {
                    subtitle = "新增知识"
                }
            } else if masteryDelta > 0 {
                priority = 80 + masteryDelta * 2 + xp
                if !domain.isEmpty {
                    subtitle = "理解深化 · \(domain)"
                } else {
                    subtitle = "掌握度提升 +\(masteryDelta)"
                }
            } else if hasPractice {
                priority = 70 + xp
                if !domain.isEmpty {
                    subtitle = "项目实践 · \(domain)"
                } else {
                    subtitle = "项目实践"
                }
            } else if hasExplanation {
                priority = 60 + xp
                if !domain.isEmpty {
                    subtitle = "理解阐释 · \(domain)"
                } else {
                    subtitle = "理解阐释"
                }
            } else if xp > 0 {
                priority = 50 + xp
                if !domain.isEmpty {
                    subtitle = "修习进境 · \(domain)"
                } else {
                    subtitle = "修习进境"
                }
            } else {
                priority = 10
                if !domain.isEmpty {
                    subtitle = "研习记录 · \(domain)"
                } else {
                    subtitle = "研习实据"
                }
            }

            items.append(
                TodayLearningItem(
                    id: nodeID.uuidString,
                    title: node.name,
                    subtitle: subtitle,
                    xp: xp,
                    nodeID: nodeID,
                    priority: priority
                )
            )
        }

        items.sort { $0.priority > $1.priority }
        return Array(items.prefix(3))
    }

    var body: some View {
        let items = learningItems

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(MenuBarPalette.cinnabar(colorScheme))

                    Text("今日所学")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(MenuBarPalette.ink(colorScheme))
                }

                Spacer()

                if todayXP > 0 {
                    HStack(spacing: 3) {
                        Text("所得")
                            .font(.system(size: 10, design: .serif))
                            .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                        Text("+\(todayXP) XP")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(MenuBarPalette.gold(colorScheme))
                    }
                }
            }
            .padding(.horizontal, 2)

            if items.isEmpty {
                if appState.pendingActivityCount > 0 {
                    Button(action: runAnalysis) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .foregroundStyle(MenuBarPalette.gold(colorScheme))
                            Text("\(appState.pendingActivityCount) 条研习活动待悟道分析")
                                .font(.system(size: 12))
                                .foregroundStyle(MenuBarPalette.ink(colorScheme))
                            Spacer()
                            Text("立即悟道")
                                .font(.system(size: 11, weight: .medium, design: .serif))
                                .foregroundStyle(MenuBarPalette.gold(colorScheme))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(MenuBarPalette.gold(colorScheme).opacity(0.08))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(MenuBarPalette.gold(colorScheme).opacity(0.25), lineWidth: 0.6)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("今日尚无新的研习记录")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                        Text("写下 Markdown 或提交代码后会呈现在此")
                            .font(.system(size: 11))
                            .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme).opacity(0.7))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button(action: { openItem(item) }) {
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(MenuBarPalette.ink(colorScheme))
                                        .lineLimit(2)

                                    Text(item.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                if item.xp > 0 {
                                    Text("+\(item.xp) XP")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(MenuBarPalette.gold(colorScheme))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(hoveredItemID == item.id ? MenuBarPalette.hoverFill(colorScheme) : .clear)
                            )
                            .contentShape(.rect)
                        }
                        .buttonStyle(MenuBarPressButtonStyle())
                        .onHover { hovering in
                            hoveredItemID = hovering ? item.id : nil
                        }
                        .accessibilityLabel("\(item.title)，\(item.subtitle)")

                        if index < items.count - 1 {
                            Divider()
                                .overlay(MenuBarPalette.divider(colorScheme))
                                .padding(.leading, 8)
                        }
                    }
                }
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            colorScheme == .dark
                                ? Color(red: 0.08, green: 0.16, blue: 0.14).opacity(0.38)
                                : Color(red: 0.94, green: 0.96, blue: 0.94).opacity(0.50)
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            MenuBarPalette.jade(colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.14),
                            lineWidth: 0.6
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func runAnalysis() {
        Task {
            await appState.runAnalysis()
        }
    }

    private func openItem(_ item: TodayLearningItem) {
        if let nodeID = item.nodeID {
            appState.selectedKnowledgeNodeID = nodeID
            appState.selectedSection = .knowledge
        } else {
            appState.selectedSection = .today
        }
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

// MARK: - 今日所学单条数据模型

private struct TodayLearningItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let xp: Int
    let nodeID: UUID?
    let priority: Int
}
