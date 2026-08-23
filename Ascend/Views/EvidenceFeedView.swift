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
            VStack(alignment: .leading, spacing: 20) {
                PageHeaderView(
                    "资料流",
                    subtitle: "每一次评分变化，都能回到原始活动与 AI 判断。",
                    systemImage: "list.bullet.rectangle"
                )

                if appState.activityEvents.isEmpty {
                    VStack(spacing: 18) {
                        ContentUnavailableView(
                            "资料流为空",
                            systemImage: "tray",
                            description: Text("添加学习来源后，采集到的提交、笔记与练习会按时间汇聚在这里。")
                        )
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                            OnboardingStepView(number: 1, title: "连接来源", detail: "选择 Git 仓库或 Markdown 目录", systemImage: "externaldrive.badge.plus")
                            OnboardingStepView(number: 2, title: "最小采集", detail: "仅保留定位、摘要与有限审计片段", systemImage: "lock.shield")
                            OnboardingStepView(number: 3, title: "等待分析", detail: "验证后才写入证据与评分账本", systemImage: "checkmark.seal")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .panelCard()
                } else {
                    HStack {
                        Picker("过滤", selection: $filter) {
                            ForEach(FilterOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)

                        Spacer()

                        Text("显示 \(paginatedEvents.count) / \(filteredEvents.count) 条")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Table(paginatedEvents) {
                        TableColumn("时间") { event in
                            Text(event.timestamp, format: .dateTime.month().day().hour().minute())
                        }
                        TableColumn("来源") { event in
                            Text(SourceKind(rawValue: event.sourceKindRawValue)?.title ?? "未知")
                        }
                        TableColumn("活动") { event in
                            VStack(alignment: .leading) {
                                Text(event.title).bold()
                                Text(event.summary).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        TableColumn("状态") { event in
                            Label(event.isProcessed ? "已分析" : "待分析", systemImage: event.isProcessed ? "checkmark.circle.fill" : "clock")
                                .foregroundStyle(event.isProcessed ? AscendTheme.jade : AscendTheme.amber)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.secondary.opacity(0.16), lineWidth: 1)
                    }

                    if filteredEvents.count > displayLimit {
                        HStack {
                            Spacer()
                            Button("加载更多 (还有 \(filteredEvents.count - displayLimit) 条)…") {
                                displayLimit += 50
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                }
            }
            .frame(maxWidth: 1_280, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .searchable(text: $searchText, prompt: "搜索活动标题或内容")
    }
}
