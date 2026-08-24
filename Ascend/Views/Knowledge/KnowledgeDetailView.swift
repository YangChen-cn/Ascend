import AppKit
import SwiftUI

struct KnowledgeDetailView: View {
    @Environment(AppState.self) private var appState
    let node: KnowledgeNode
    let mastery: MasteryState
    var onClose: (() -> Void)? = nil

    @State private var selectedNotePreview: ActivityEvent? = nil
    @State private var showsPerformanceAttainment = false

    /// 融会及以上（或综合掌握 ≥60）才提供实作认证入口，低境界不引入实作噪音
    private var showsProductionEntry: Bool {
        guard let readiness = appState.readiness(for: node.id) else { return false }
        return readiness.certifiedStage.level >= MasteryStage.integrated.level || readiness.currentComposite >= 60
    }

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
                            title: readiness.stageDisplayTitle,
                            style: badgeStyle(for: readiness.certifiedStage)
                        )

                        AssessmentLaunchButton(nodeID: node.id)

                        if showsProductionEntry {
                            Button {
                                showsPerformanceAttainment = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "hammer.and.anvil")
                                    Text("登记实作")
                                }
                            }
                            .buttonStyle(.bordered)
                            .help("把真实项目中的独立实作登记为生产性证据，用于突破化用与通达（本地结算 · 0 AI）")
                        }

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
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], alignment: .leading, spacing: 10) {
                            statItem(title: "记忆状态", value: memoryLevelTitle)
                                .help(memoryLevelTitle == "尚未安排温故" ? "尚未安排温故" : "当前记忆可提取率 \(Int(readiness.retention.rounded()))%")
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

                            Text(appState.latestInsight(for: node.id) ?? (readiness.isCertified ? "已完成实作与主动印证，表现可信。" : "学习材料已沉淀并推动推定成长。若需突破融会境界，可发起轻量主动验证。"))
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

                if let blockReason = readiness.stageBlockReason {
                    Label(blockReason, systemImage: blockReason.contains("温故") ? "arrow.clockwise.circle.fill" : "lock.fill")
                        .font(.callout)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AscendTheme.gold.opacity(0.08))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AscendTheme.gold.opacity(0.30), lineWidth: 0.8)
                        }
                }

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

                // 关联知识网络与先导脉络
                ConceptLineagePathwayView(nodeID: node.id)

                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                // 破境指引
                NextStageView(nodeID: node.id, readiness: readiness)

                // 实作认证记录
                if !nodePerformanceReceipts.isEmpty {
                    performanceReceiptSection(receipts: nodePerformanceReceipts)
                }
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
        .sheet(isPresented: $showsPerformanceAttainment) {
            PerformanceAttainmentView(node: node)
        }
    }

    /// 记忆状态以三档语义呈现，避免把 FSRS 可提取率变成需要理解的百分比
    private var memoryLevelTitle: String {
        guard appState.currentRetention(for: node.id) != nil, readiness.retention > 0 else {
            return "尚未安排温故"
        }
        switch readiness.retention {
        case ..<60: return "需温故"
        case ..<85: return "略有生疏"
        default: return "记得牢"
        }
    }

    private var nodePerformanceReceipts: [PerformanceReceipt] {
        (appState.performanceReceiptsByNodeID[node.id] ?? [])
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    private func performanceReceiptSection(receipts: [PerformanceReceipt]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "hammer.and.anvil")
                    .foregroundStyle(AscendTheme.gold)
                Text("实作认证")
                    .font(.system(.subheadline, design: AscendTheme.titleDesign))
                    .bold()
                Spacer()
                Text("\(receipts.count) 次独立实作")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(receipts) { receipt in
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: receipt.verificationLevel == .productionDeterministic ? "checkmark.seal.fill" : "checkmark.circle.fill")
                            .foregroundStyle(AscendTheme.jade)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(receipt.summary)
                                .font(.callout)
                                .lineLimit(1)
                            Text(receipt.timestampText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        CelestialBadge(
                            title: receipt.passed ? "通过" : "未通过",
                            style: receipt.passed ? .jade : .cinnabar
                        )
                    }
                    .padding(.vertical, 2)
                }
            }
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
