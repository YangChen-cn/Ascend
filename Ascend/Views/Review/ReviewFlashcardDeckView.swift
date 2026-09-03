import SwiftUI

struct ReviewFlashcardDeckView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let duePlans: [ReviewPlan]
    var onPlanCompleted: ((ReviewPlan) -> Void)? = nil

    @State private var currentIndex = 0
    @State private var isRevealed = false
    @State private var isSubmitting = false
    @State private var selectedNotePreview: ActivityEvent? = nil

    private var currentPlan: ReviewPlan? {
        guard duePlans.indices.contains(currentIndex) else { return nil }
        return duePlans[currentIndex]
    }

    private var currentNode: KnowledgeNode? {
        guard let currentPlan else { return nil }
        return appState.node(for: currentPlan.knowledgeNodeID)
    }

    private var currentReadiness: MasteryReadinessSnapshot? {
        guard let currentPlan else { return nil }
        return appState.readiness(for: currentPlan.knowledgeNodeID)
    }

    private var keyPoints: [String] {
        guard let currentPlan else { return [] }
        return appState.reviewKeyPoints(for: currentPlan.knowledgeNodeID)
    }

    private var linkedActivities: [ActivityEvent] {
        guard let currentPlan else { return [] }
        return appState.linkedActivities(for: currentPlan.knowledgeNodeID)
    }

    private var markdownActivities: [ActivityEvent] {
        linkedActivities.filter(ReviewActivityLocator.isMarkdownNote)
    }

    private var otherEvidenceActivities: [ActivityEvent] {
        linkedActivities.filter { !ReviewActivityLocator.isMarkdownNote($0) }
    }

    /// 只有能解析到具体 .md 文件的活动才提供笔记预览，不再回退到代码或测评活动。
    private var preferredNoteActivity: ActivityEvent? {
        markdownActivities.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if duePlans.isEmpty {
                allCompletedBanner
            } else if let plan = currentPlan, let node = currentNode {
                // 顶部进度与提示
                deckHeader

                // 主知识卡片
                flashcardContainer(plan: plan, node: node)
            } else {
                allCompletedBanner
            }
        }
        .onChange(of: duePlans.map(\.id)) { _, newIDs in
            if currentIndex >= newIDs.count {
                currentIndex = max(0, newIDs.count - 1)
                isRevealed = false
            }
        }
        .sheet(item: $selectedNotePreview) { activity in
            MarkdownNotePreviewSheet(activity: activity)
        }
    }

    // MARK: - 顶部进度栏
    private var deckHeader: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(AscendTheme.gold)

                Text(AscendTheme.isXuanqing ? "今日温故知窍" : "今日到期复习")
                    .font(.system(.headline, design: AscendTheme.titleDesign))
                    .bold()

                CelestialBadge(
                    title: "今日剩余 \(duePlans.count) 项",
                    style: .gold
                )
            }

            Spacer()
        }
    }

    // MARK: - 知识卡容器
    @ViewBuilder
    private func flashcardContainer(plan: ReviewPlan, node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // 卡片头部：知窍名称、领域、境界以及直接呼出笔记预览
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(node.name)
                        .font(.system(.title2, design: AscendTheme.titleDesign))
                        .bold()

                    HStack(spacing: 6) {
                        CelestialBadge(
                            title: node.domain,
                            systemImage: "folder.fill",
                            style: .astral
                        )
                        if let stage = currentReadiness?.certifiedStage {
                            CelestialBadge(
                                title: stage.rawValue,
                                systemImage: "seal.fill",
                                style: .gold
                            )
                        }
                    }
                }

                Spacer()

                if let noteActivity = preferredNoteActivity {
                    Button {
                        selectedNotePreview = noteActivity
                    } label: {
                        Label("预览笔记", systemImage: "doc.text.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("预览 \(ReviewActivityLocator.markdownDisplayName(for: noteActivity) ?? "关联 Markdown 笔记")")
                }
            }

            Divider()
                .overlay(AscendTheme.gold.opacity(0.12))

            if !isRevealed {
                // 正面：回忆提示区
                frontRecallSection
            } else {
                // 背面：要点与自评区
                backRevealedSection(plan: plan)
            }
        }
        .sectionSurface(.emphasized)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isRevealed)
    }

    // MARK: - 卡片正面：主动回忆引导
    private var frontRecallSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundStyle(AscendTheme.jade)
                    Text("回忆提示")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()
                }

                Text("你还记得「\(currentNode?.name ?? "这个知识点")」的核心作用、关键设计与实践要点吗？")
                    .font(.body)
                    .foregroundStyle(.primary)

                if let hint = recallHint {
                    Text(hint)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 8)

            HStack {
                Spacer()

                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        isRevealed = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("查看要点")
                            .bold()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
                .keyboardShortcut(.space, modifiers: [])

                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - 卡片背面：本地要点与自评按钮
    @ViewBuilder
    private func backRevealedSection(plan: ReviewPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 本地提取的关键要点
            VStack(alignment: .leading, spacing: 8) {
                Text("知窍要点与实据回顾")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(keyPoints.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(.caption, design: .rounded))
                                .bold()
                                .foregroundStyle(AscendTheme.jade)
                            Text(point)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 只有真实 Markdown 文件显示为可点击笔记；代码与测评仅列为实据摘要。
            if !markdownActivities.isEmpty || !otherEvidenceActivities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !markdownActivities.isEmpty {
                        Text("可读 Markdown 笔记")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(Array(markdownActivities.prefix(3))) { act in
                            Button {
                                selectedNotePreview = act
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.caption)
                                        .foregroundStyle(AscendTheme.jade)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(ReviewActivityLocator.markdownDisplayName(for: act) ?? act.title)
                                            .font(.caption)
                                            .bold()
                                            .lineLimit(1)
                                        Text(act.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !otherEvidenceActivities.isEmpty {
                        Text(markdownActivities.isEmpty ? "暂无可读 Markdown 笔记；以下为已验证实据摘要" : "其他已验证实据")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, markdownActivities.isEmpty ? 0 : 4)

                        ForEach(Array(otherEvidenceActivities.prefix(3))) { act in
                            HStack(spacing: 8) {
                                Image(systemName: act.sourceLocator.hasPrefix("assessment/") ? "checkmark.seal" : "chevron.left.forwardslash.chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(AscendTheme.jade)
                                Text(act.title)
                                    .font(.caption)
                                    .bold()
                                    .lineLimit(1)
                                Text(act.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }

            Divider()
                .overlay(AscendTheme.gold.opacity(0.12))

            // 自评区域：四个 FSRS 按钮
            VStack(alignment: .leading, spacing: 10) {
                Text("回忆自评（FSRS 间隔推演）：")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    selfGradeButton(
                        grade: .again,
                        title: "忘了",
                        subtitle: "重新加固",
                        color: AscendTheme.cinnabar,
                        shortcutKey: "1",
                        plan: plan
                    )
                    selfGradeButton(
                        grade: .hard,
                        title: "有点模糊",
                        subtitle: "较难想起",
                        color: AscendTheme.gold,
                        shortcutKey: "2",
                        plan: plan
                    )
                    selfGradeButton(
                        grade: .good,
                        title: "记得",
                        subtitle: "顺利提取",
                        color: AscendTheme.jade,
                        shortcutKey: "3",
                        plan: plan
                    )
                    selfGradeButton(
                        grade: .easy,
                        title: "很熟",
                        subtitle: "清晰掌握",
                        color: AscendTheme.cobalt,
                        shortcutKey: "4",
                        plan: plan
                    )
                }
            }
        }
    }

    // MARK: - 自评按钮组件
    private func selfGradeButton(
        grade: MemoryReviewGrade,
        title: String,
        subtitle: String,
        color: Color,
        shortcutKey: KeyEquivalent,
        plan: ReviewPlan
    ) -> some View {
        Button {
            submitGrade(grade, for: plan)
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: AscendTheme.titleDesign))
                    .bold()
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcutKey, modifiers: [])
        .disabled(isSubmitting)
    }

    // MARK: - 提交自评逻辑
    private func submitGrade(_ grade: MemoryReviewGrade, for plan: ReviewPlan) {
        guard !isSubmitting else { return }
        isSubmitting = true
        do {
            try appState.completeCardReview(for: plan, grade: grade)
            onPlanCompleted?(plan)
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                isRevealed = false
                isSubmitting = false
            }
        } catch {
            appState.statusMessage = "记录温故失败：\(error.localizedDescription)"
            isSubmitting = false
        }
    }

    // MARK: - 全部完成横幅
    private var allCompletedBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AscendTheme.jade.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(AscendTheme.jade)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AscendTheme.isXuanqing ? "灵台明澈 · 今日温故已全部完成" : "今日到期复习已全部完成")
                    .font(.system(.headline, design: AscendTheme.titleDesign))
                    .bold()
                Text("已完成今日全部到期知窍的主动检索与 FSRS 记忆加固。系统将随时间继续推演最佳温故时机。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .sectionSurface(.grouped)
    }

    /// 用已验证证据摘要生成一行节点特定回忆引导，替代所有卡片同一句通用文案；
    /// 不暴露完整要点，保留回忆空间
    private var recallHint: String? {
        guard let currentPlan,
              let summary = appState.linkedActivities(for: currentPlan.knowledgeNodeID).first?.summary,
              !summary.isEmpty
        else { return nil }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return nil }
        let prefix = trimmed.prefix(42)
        return "提示：\(prefix)\(trimmed.count > prefix.count ? "…" : "")\n先自主检索回忆，再点击下方查看要点比对。"
    }
}
