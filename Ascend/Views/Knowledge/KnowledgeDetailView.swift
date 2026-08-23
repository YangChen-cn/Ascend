import AppKit
import SwiftUI

struct KnowledgeDetailView: View {
    @Environment(AppState.self) private var appState
    let node: KnowledgeNode
    let mastery: MasteryState
    var onClose: (() -> Void)? = nil

    @State private var selectedNotePreview: ActivityEvent? = nil

    private var readiness: MasteryReadinessSnapshot {
        appState.readiness(for: node.id) ?? MasteryReadinessSnapshot(
            knowledgeNodeID: node.id,
            historicalVector: mastery.vector,
            currentVector: mastery.vector,
            historicalStage: mastery.highestStage,
            currentStage: mastery.stage
        )
    }

    private var evidence: [EvidenceRecord] {
        appState.evidenceRecords(for: node.id)
    }

    private var linkedActivities: [ActivityEvent] {
        let activityIDs = Set(evidence.map(\.activityID))
        return appState.activityEvents.filter { activityIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 顶部标题玉简与关闭按钮
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        Text(node.domain)
                            .font(.system(.caption, design: AscendTheme.titleDesign))
                            .foregroundStyle(.secondary)

                        Spacer()

                        CelestialBadge(
                            title: "最高 · \(readiness.historicalStage.rawValue)",
                            style: badgeStyle(for: readiness.historicalStage)
                        )

                        if let onClose {
                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("关闭面板 (Esc)")
                            .keyboardShortcut(.escape, modifiers: [])
                            .padding(.leading, 4)
                        }
                    }

                    Text(node.name)
                        .font(.system(.title, design: AscendTheme.titleDesign))
                        .bold()
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                }

                // 核心掌握度环与指标
                HStack(alignment: .center, spacing: 20) {
                    MasteryRingView(score: readiness.currentComposite)

                    VStack(alignment: .leading, spacing: 10) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 10)], alignment: .leading, spacing: 10) {
                            statItem(title: "历史掌握", value: "\(Int(readiness.historicalComposite.rounded()))")
                            statItem(title: "当前状态", value: "\(Int(readiness.currentComposite.rounded()))")
                            statItem(title: "记忆保持", value: "\(Int(readiness.retention.rounded()))")
                            statItem(title: "累积知验", value: "\(mastery.lifetimeXP) XP")
                        }

                        // 悟得真传提示框
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(AscendTheme.gold)
                                    .font(.caption2)
                                Text("悟得真意")
                                    .font(.system(.caption, design: AscendTheme.titleDesign))
                                    .bold()
                                    .foregroundStyle(AscendTheme.gold)
                            }

                            Text(appState.latestInsight(for: node.id) ?? "尚无已验证的悟得实据。继续在代码与笔记中深入实践或独立解决以凝练精义。")
                                .font(.system(.caption, design: AscendTheme.titleDesign))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(AscendTheme.gold.opacity(0.20), lineWidth: 0.8)
                        }
                    }
                }

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 五维雷达条带
                MasteryDimensionStrip(vector: readiness.currentVector)

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 关联研习笔记与实据文件
                linkedNotesSection

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 历史实据与衰减轨迹
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        EvidenceLedgerView(nodeID: node.id)
                            .frame(width: 250)
                        MasteryTrajectoryView(nodeID: node.id)
                            .frame(width: 280)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        EvidenceLedgerView(nodeID: node.id)
                        MasteryTrajectoryView(nodeID: node.id)
                    }
                }

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 关联知识网络
                KnowledgeRelationsView(nodeID: node.id)

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 破境指引
                NextStageView(nodeID: node.id, readiness: readiness)
            }
            .padding(22)
        }
        .background(FeaturePageBackground())
        .sheet(item: $selectedNotePreview) { activity in
            MarkdownNotePreviewSheet(
                title: activity.title,
                fileLocator: activity.sourceLocator,
                excerpt: activity.excerpt,
                timestamp: activity.timestamp
            )
        }
    }

    // MARK: - 关联笔记与实据来源

    private var linkedNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(AscendTheme.gold)
                    Text("关联研习笔记与实据")
                        .font(.system(.subheadline, design: AscendTheme.titleDesign))
                        .bold()
                }

                Spacer()

                Text("\(linkedActivities.count) 个来源")
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(.secondary)
            }

            if linkedActivities.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("暂无关联的笔记或代码提交")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(linkedActivities) { activity in
                        linkedActivityRow(activity: activity)
                    }
                }
            }
        }
    }

    private func linkedActivityRow(activity: ActivityEvent) -> some View {
        let isMarkdown = activity.sourceKindRawValue == SourceKind.markdownDirectory.rawValue ||
                         activity.sourceKindRawValue == SourceKind.remoteGitRepository.rawValue ||
                         activity.sourceKindRawValue == SourceKind.remoteGitMarkdown.rawValue ||
                         activity.sourceLocator.hasSuffix(".md")

        return HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(isMarkdown ? AscendTheme.jade.opacity(0.15) : AscendTheme.cobalt.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: isMarkdown ? "doc.text.fill" : "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundStyle(isMarkdown ? AscendTheme.jade : AscendTheme.cobalt)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(.callout, design: .serif))
                    .bold()
                    .lineLimit(1)

                Text(activity.summary)
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { selectedNotePreview = activity }) {
                Label(isMarkdown ? "预览笔记" : "查看实据", systemImage: isMarkdown ? "eye.fill" : "doc.text")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            if isMarkdown {
                Button(action: { revealInFinder(path: activity.sourceLocator) }) {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("在访达中显示文件")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AscendTheme.border(for: .light), lineWidth: 0.8)
        }
    }

    private func revealInFinder(path: String) {
        let cleanPath = path.components(separatedBy: "#").first ?? path
        let url = URL(fileURLWithPath: cleanPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: AscendTheme.titleDesign))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .rounded))
                .bold()
        }
    }

    private func badgeStyle(for stage: MasteryStage) -> CelestialBadgeStyle {
        switch stage {
        case .mastered, .connected: .gold
        case .integrated: .jade
        case .proficient: .astral
        case .advancing, .entry: .neutral
        }
    }
}
