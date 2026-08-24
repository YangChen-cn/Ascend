import SwiftUI

struct ReviewQueueView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedDomain: String? = nil
    @State private var showsCompletedSection = false
    @State private var activeReviewPlan: ReviewPlan? = nil

    private var duePlans: [ReviewPlan] {
        appState.reviewPlans
            .filter { $0.status == "due" }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var scheduledPlans: [ReviewPlan] {
        appState.reviewPlans
            .filter { $0.status == "scheduled" }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var completedPlans: [ReviewPlan] {
        appState.reviewPlans
            .filter { $0.status == "completed" }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    private var allDomains: [String] {
        let nodeIDs = Set(appState.reviewPlans.map(\.knowledgeNodeID))
        let domains = nodeIDs.compactMap { appState.node(for: $0)?.domain }
        return Array(Set(domains)).sorted()
    }

    private var filteredDuePlans: [ReviewPlan] {
        guard let selectedDomain else { return duePlans }
        return duePlans.filter { appState.node(for: $0.knowledgeNodeID)?.domain == selectedDomain }
    }

    private var filteredScheduledPlans: [ReviewPlan] {
        guard let selectedDomain else { return scheduledPlans }
        return scheduledPlans.filter { appState.node(for: $0.knowledgeNodeID)?.domain == selectedDomain }
    }

    private var filteredCompletedPlans: [ReviewPlan] {
        guard let selectedDomain else { return completedPlans }
        return completedPlans.filter { appState.node(for: $0.knowledgeNodeID)?.domain == selectedDomain }
    }

    private var averageRetention: Double {
        let validRetentions = appState.knowledgeNodes.compactMap { appState.currentRetention(for: $0.id) }
        guard !validRetentions.isEmpty else { return 100 }
        return validRetentions.reduce(0, +) / Double(validRetentions.count)
    }

    var body: some View {
        ZStack {
            FeaturePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // 顶部抬头面板与统计徽章
                    headerPanel
                        .panelCard()

                    // 领域筛选（当跨多个领域时呈现）
                    if allDomains.count > 1 {
                        domainFilterBar
                    }

                    // 主内容区：两栏式响应布局
                    if duePlans.isEmpty && scheduledPlans.isEmpty && completedPlans.isEmpty {
                        HStack(alignment: .top, spacing: 18) {
                            ReviewEmptyStateView()
                                .panelCard()
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ReviewScienceRailView()
                                .frame(width: 350)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 18) {
                            mainPlanColumn
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ReviewScienceRailView()
                                .frame(width: 350)
                        }
                    }
                }
                .frame(maxWidth: 1_280, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(AscendTheme.isXuanqing ? "温故知新" : "到期复习")
    }

    // MARK: - 顶部面板
    private var headerPanel: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AscendTheme.isXuanqing ? "温故知新 · 记忆推演" : "到期复习")
                    .font(.system(.largeTitle, design: AscendTheme.titleDesign))
                    .bold()
                Text("基于 FSRS 间隔重复算法，在遗忘临界点主动回忆，重塑长期记忆深度；本地轻量秒级流转，全程 0 次 AI 调用。")
                    .font(.system(.callout, design: AscendTheme.titleDesign))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                CelestialBadge(
                    title: "待温故",
                    subtitle: "\(duePlans.count)",
                    systemImage: "clock.badge.exclamationmark.fill",
                    style: .cinnabar
                )
                CelestialBadge(
                    title: "即将到期",
                    subtitle: "\(scheduledPlans.count)",
                    systemImage: "calendar.badge.clock",
                    style: .gold
                )
                CelestialBadge(
                    title: "已固道基",
                    subtitle: "\(completedPlans.count)",
                    systemImage: "checkmark.seal.fill",
                    style: .jade
                )
                CelestialBadge(
                    title: "平均留存",
                    subtitle: "\(Int(averageRetention.rounded()))%",
                    systemImage: "waveform.path.ecg",
                    style: .astral
                )
            }
        }
    }

    // MARK: - 领域筛选栏
    private var domainFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部领域", count: duePlans.count + scheduledPlans.count, isSelected: selectedDomain == nil) {
                    selectedDomain = nil
                }
                ForEach(allDomains, id: \.self) { domain in
                    let count = (duePlans + scheduledPlans).count { appState.node(for: $0.knowledgeNodeID)?.domain == domain }
                    FilterChip(title: domain, count: count, isSelected: selectedDomain == domain) {
                        selectedDomain = domain
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 主复习计划流
    private var mainPlanColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 快速回忆知识卡轮播甲板
            if !filteredDuePlans.isEmpty {
                ReviewFlashcardDeckView(duePlans: filteredDuePlans)
            } else if let target = activeReviewPlan {
                ReviewFlashcardDeckView(duePlans: [target]) { _ in
                    activeReviewPlan = nil
                }
            } else {
                // 到期任务为空时的温和提示
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(AscendTheme.jade)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AscendTheme.isXuanqing ? "灵台明澈 · 当前无到期复习" : "当前无到期复习任务")
                            .font(.system(.headline, design: AscendTheme.titleDesign))
                            .bold()
                        Text(scheduledPlans.isEmpty
                            ? "有新的研习沉淀后，系统会自动安排间隔温故。"
                            : "已排期的知窍将在到达遗忘临界点时自动转入待温故队列。")
                            .font(.system(.caption, design: AscendTheme.titleDesign))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .panelCard()
            }

            // 即将到期的知窍列表
            if !filteredScheduledPlans.isEmpty {
                ReviewPlanSectionView(
                    title: "即将到期",
                    systemImage: "calendar.badge.clock",
                    plans: filteredScheduledPlans,
                    startingPlanID: nil,
                    start: { plan in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeReviewPlan = plan
                        }
                    }
                )
            }

            // 近期已完成温故
            if !filteredCompletedPlans.isEmpty {
                DisclosureGroup(
                    isExpanded: $showsCompletedSection,
                    content: {
                        VStack(spacing: 12) {
                            ForEach(filteredCompletedPlans.prefix(10)) { plan in
                                ReviewPlanCardView(
                                    plan: plan,
                                    isStarting: false,
                                    onStart: nil
                                )
                            }
                        }
                        .padding(.top, 10)
                    },
                    label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(AscendTheme.jade)
                            Text("近期已温故（\(filteredCompletedPlans.count)）")
                                .font(.system(.headline, design: AscendTheme.titleDesign))
                                .bold()
                        }
                    }
                )
                .panelCard()
            }
        }
    }
}

// MARK: - 筛选 Chip 组件
private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(.subheadline, design: AscendTheme.titleDesign))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(.caption2, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? AscendTheme.jade : Color.primary.opacity(0.04))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? AscendTheme.jade : Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
