import SwiftUI

struct EvidenceFeedView: View {
    @Environment(AppState.self) private var appState
    @State private var filter: FilterOption = .all
    @State private var searchText = ""
    @State private var displayLimit = 50

    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "全部"
        case pending = "待分析"
        case processed = "已分析"

        var id: Self { self }
    }

    private var filteredEvents: [ActivityEvent] {
        let base: [ActivityEvent]
        switch filter {
        case .all: base = appState.activityEvents
        case .pending: base = appState.activityEvents.filter { !$0.isProcessed }
        case .processed: base = appState.activityEvents.filter { $0.isProcessed }
        }
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.title.localizedStandardContains(searchText) ||
            $0.summary.localizedStandardContains(searchText) ||
            $0.sourceLocator.localizedStandardContains(searchText)
        }
    }

    private var paginatedEvents: [ActivityEvent] {
        Array(filteredEvents.prefix(displayLimit))
    }

    var body: some View {
        ZStack {
            FeaturePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 顶部仙家抬头与数据统计徽章
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("研习资料流")
                                .font(.system(.largeTitle, design: .serif))
                                .bold()
                            Text("每一次评分变动与境界进阶，皆可溯回至原始活动与 AI 研习判断。")
                                .font(.system(.callout, design: .serif))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            CelestialBadge(
                                title: "总实据",
                                subtitle: "\(appState.activityEvents.count)",
                                systemImage: "tray.full.fill",
                                style: .astral
                            )
                            CelestialBadge(
                                title: "待分析",
                                subtitle: "\(appState.activityEvents.count { !$0.isProcessed })",
                                systemImage: "clock.fill",
                                style: .cinnabar
                            )
                            CelestialBadge(
                                title: "数据源",
                                subtitle: "\(appState.sources.count)",
                                systemImage: "circle.circle.fill",
                                style: .jade
                            )
                        }
                    }
                    .panelCard()

                    if appState.activityEvents.isEmpty {
                        // 空状态：仙家空状态与接引指南
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(AscendTheme.gold.opacity(0.12))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "tray")
                                        .font(.title)
                                        .foregroundStyle(AscendTheme.gold)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("资料流空空如也 · 待起法舟")
                                        .font(.system(.title2, design: .serif))
                                        .bold()
                                    Text("万丈高楼起于垒土。连接 Git 仓库或研习笔记后，采集到的提交、改动与练习将按时在此汇聚成卷。")
                                        .font(.system(.callout, design: .serif))
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(4)
                                }
                            }
                            .padding(.vertical, 8)

                            Divider()
                                .overlay(AscendTheme.gold.opacity(0.15))

                            Text("修真研习三步法门")
                                .font(.system(.headline, design: .serif))
                                .bold()

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                                onboardingStepCard(
                                    step: "壹",
                                    title: "连接研习来源",
                                    desc: "选择本地 Git 代码仓库或 Markdown 笔记目录，支持多仓库分支追踪。",
                                    icon: "externaldrive.badge.plus",
                                    badgeStyle: .jade
                                )

                                onboardingStepCard(
                                    step: "贰",
                                    title: "最小审计采集",
                                    desc: "仅提取定位、哈希、摘要与有限代码片段，杜绝上传敏感代码与隐私内容。",
                                    icon: "lock.shield.fill",
                                    badgeStyle: .astral
                                )

                                onboardingStepCard(
                                    step: "叁",
                                    title: "验证悟道入库",
                                    desc: "AI 识别并经由置信度验证或待确认审核后，方才写入五维掌握度与知验账本。",
                                    icon: "checkmark.seal.fill",
                                    badgeStyle: .gold
                                )
                            }

                            // 底部中国水墨远山画卷
                            InkLandscapeWatermark(height: 90, opacity: 0.70)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .panelCard()
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Picker("过滤", selection: $filter) {
                                    ForEach(FilterOption.allCases) { opt in
                                        Text(opt.rawValue).tag(opt)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 280)

                                Spacer()

                                Text("显示 \(paginatedEvents.count) / \(filteredEvents.count) 条实据")
                                    .font(.system(.callout, design: .serif))
                                    .foregroundStyle(.secondary)
                            }

                            Table(paginatedEvents) {
                                TableColumn("时间") { event in
                                    Text(event.timestamp, format: .dateTime.month().day().hour().minute())
                                        .font(.system(.callout, design: .rounded))
                                }
                                .width(ideal: 120)

                                TableColumn("来源") { event in
                                    Text(SourceKind(rawValue: event.sourceKindRawValue)?.title ?? "未知")
                                        .font(.system(.callout, design: .serif))
                                }
                                .width(ideal: 110)

                                TableColumn("研习活动") { event in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title)
                                            .font(.system(.body, design: .serif))
                                            .bold()
                                        Text(event.summary)
                                            .font(.system(.caption, design: .serif))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                TableColumn("状态") { event in
                                    CelestialBadge(
                                        title: event.isProcessed ? "已悟道" : "待分析",
                                        systemImage: event.isProcessed ? "checkmark.circle.fill" : "clock",
                                        style: event.isProcessed ? .jade : .cinnabar
                                    )
                                }
                                .width(ideal: 100)
                            }
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AscendTheme.gold.opacity(0.18), lineWidth: 1)
                            }
                            .frame(minHeight: 480)

                            if filteredEvents.count > displayLimit {
                                HStack {
                                    Spacer()
                                    Button("加载更多实据 (尚有 \(filteredEvents.count - displayLimit) 条)…") {
                                        displayLimit += 50
                                    }
                                    .buttonStyle(.bordered)
                                    Spacer()
                                }
                                .padding(.top, 6)
                            }
                        }
                        .panelCard()
                    }
                }
                .frame(maxWidth: 1_280, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .searchable(text: $searchText, prompt: "搜索活动标题、摘要或来源路径")
    }

    private func onboardingStepCard(step: String, title: String, desc: String, icon: String, badgeStyle: CelestialBadgeStyle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 26, height: 26)
                    Text(step)
                        .font(.system(.caption, design: .serif))
                        .bold()
                }

                Spacer()

                CelestialBadge(title: title, systemImage: icon, style: badgeStyle)
            }

            Text(desc)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AscendTheme.gold.opacity(0.18), lineWidth: 0.8)
        }
    }
}
