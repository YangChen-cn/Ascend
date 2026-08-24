import SwiftUI

struct EvidenceFeedView: View {
    @Environment(AppState.self) private var appState
    @State private var filter: ActivityFeedFilter = .all
    @State private var searchText = ""
    @State private var displayLimit = 50
    @State private var selectedEventIDs = Set<UUID>()
    @State private var showsReanalysisConfirmation = false
    @State private var showsStopTrackingConfirmation = false

    private var paginatedEvents: [ActivityEvent] { appState.activityFeedEvents }

    private var tableHeight: CGFloat {
        min(520, max(240, CGFloat(paginatedEvents.count) * 38 + 44))
    }

    var body: some View {
        AppPageScaffold {
                    ResponsivePageHeader {
                        PageHeaderView(
                            "研习资料流",
                            subtitle: "每一次评分变动与境界进阶，皆可溯回至原始活动与 AI 研习判断。",
                            systemImage: "tray.full.fill"
                        )

                    } actions: {
                        HStack(spacing: 8) {
                            CelestialBadge(
                                title: "总实据",
                                subtitle: "\(appState.totalActivityCount)",
                                systemImage: "tray.full.fill",
                                style: .jade
                            )
                            CelestialBadge(
                                title: "待分析",
                                subtitle: "\(appState.pendingActivityCount)",
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

                    if appState.totalActivityCount == 0 {
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
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(4)
                                }
                            }
                            .padding(.vertical, 8)

                            HStack(spacing: 10) {
                                TargetedSettingsButton(section: .sources) {
                                    Label("配置研习来源", systemImage: "externaldrive.badge.plus")
                                }
                                .buttonStyle(.borderedProminent)

                                Button("巡察并分析", systemImage: "sparkles", action: analyze)
                                    .buttonStyle(.bordered)
                                    .disabled(appState.isAnalyzing)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sectionSurface(.grouped)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Picker("过滤", selection: $filter) {
                                    ForEach(ActivityFeedFilter.allCases) { opt in
                                        Text(opt.rawValue).tag(opt)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 280)

                                Spacer()

                                if !selectedEventIDs.isEmpty {
                                    Button("清除选择", action: { selectedEventIDs.removeAll() })
                                    Button(
                                        "删除跟踪所选（\(selectedEventIDs.count)）",
                                        systemImage: "trash",
                                        role: .destructive
                                    ) {
                                        showsStopTrackingConfirmation = true
                                    }
                                    .disabled(appState.isAnalyzing)
                                    .confirmationDialog(
                                        "删除并停止跟踪所选活动？",
                                        isPresented: $showsStopTrackingConfirmation
                                    ) {
                                        Button("删除跟踪", role: .destructive, action: stopTrackingSelection)
                                    } message: {
                                        Text("将删除所选活动及其派生证据，并按剩余真实证据重放评分。对应笔记后续发生更新时也不会再次被收录。")
                                    }
                                    Button("重新分析所选（\(selectedEventIDs.count)）", systemImage: "arrow.clockwise") {
                                        showsReanalysisConfirmation = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(appState.isAnalyzing)
                                    .confirmationDialog(
                                        "重新分析并覆盖所选活动？",
                                        isPresented: $showsReanalysisConfirmation
                                    ) {
                                        Button("重新分析并覆盖", role: .destructive, action: reanalyzeSelection)
                                    } message: {
                                        Text("将在新分析成功后替换所选活动的旧证据并重放评分。该操作会调用当前 AI 模型并产生 Token 费用。")
                                    }
                                }

                                Text("显示 \(paginatedEvents.count) / \(appState.activityFeedTotalCount) 条实据")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            Text("按住 Command 可逐条多选，按住 Shift 可连续选择。")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            Table(paginatedEvents, selection: $selectedEventIDs) {
                                TableColumn("时间") { event in
                                    Text(event.timestamp, format: .dateTime.month().day().hour().minute())
                                        .font(.system(.callout, design: .rounded))
                                }
                                .width(ideal: 120)

                                TableColumn("来源") { event in
                                    Text(SourceKind(rawValue: event.sourceKindRawValue)?.title ?? "未知")
                                        .font(.callout)
                                }
                                .width(ideal: 110)

                                TableColumn("研习活动") { event in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title)
                                            .font(.body)
                                            .bold()
                                        Text(event.summary)
                                            .font(.caption)
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
                            .frame(height: tableHeight)

                            if appState.activityFeedTotalCount > displayLimit {
                                HStack {
                                    Spacer()
                                    Button("加载更多实据 (尚有 \(appState.activityFeedTotalCount - displayLimit) 条)…") {
                                        displayLimit += 50
                                        loadPage()
                                    }
                                    .buttonStyle(.bordered)
                                    Spacer()
                                }
                                .padding(.top, 6)
                            }
                        }
                        .sectionSurface(.grouped)
                    }
        }
        .searchable(text: $searchText, prompt: "搜索活动标题、摘要或来源路径")
        .task(id: FeedQuery(filter: filter, searchText: searchText, limit: displayLimit)) {
            if !searchText.isEmpty {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            loadPage()
            selectedEventIDs.formIntersection(Set(appState.activityFeedEvents.map(\.id)))
        }
    }

    private func reanalyzeSelection() {
        let activityIDs = selectedEventIDs
        Task {
            await appState.reanalyze(activityIDs: activityIDs)
            if appState.statusMessage?.hasPrefix("已重新分析并覆盖") == true {
                selectedEventIDs.removeAll()
            }
            loadPage()
        }
    }

    private func analyze() {
        Task { await appState.runAnalysis() }
    }

    private func stopTrackingSelection() {
        do {
            try appState.stopTracking(activityIDs: selectedEventIDs)
            selectedEventIDs.removeAll()
            loadPage()
        } catch {
            appState.statusMessage = "删除跟踪失败：\(error.localizedDescription)"
        }
    }

    private func loadPage() {
        appState.loadActivityFeed(filter: filter, searchText: searchText, limit: displayLimit)
    }

}

private struct FeedQuery: Equatable {
    let filter: ActivityFeedFilter
    let searchText: String
    let limit: Int
}
