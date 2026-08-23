import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isScanning = false

    private var leadingDomain: DomainProgressSnapshot? {
        appState.domainProgress.first
    }

    private var todayTotalXP: Int {
        appState.todayXPGains.reduce(0) { $0 + $1.xp }
    }

    private var urgentForgettingNode: ForgettingProjection? {
        appState.forgettingProjections.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部 Header
            headerSection
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [
                            AscendTheme.gold.opacity(colorScheme == .dark ? 0.15 : 0.10),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Divider()

            // 2. 核心信息面板（采用自然高度排版，杜绝 ScrollView 折叠）
            VStack(spacing: 10) {
                // 灵机巡察与分析状态
                statusSection

                // 首席灵根与修行境界
                if let leading = leadingDomain {
                    realmProgressCard(domain: leading)
                }

                // 今日精进知验
                todayGainsSection

                // 急需温故提醒（如有）
                if let projection = urgentForgettingNode {
                    forgettingRecallCard(projection: projection)
                }
            }
            .padding(14)

            Divider()

            // 3. 底部快捷操作栏
            footerActionsSection
                .padding(12)
                .background(.ultraThinMaterial)
        }
        .frame(width: 320)
    }

    // MARK: - 1. 顶部 Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(AscendTheme.goldGradient)
                    .frame(width: 38, height: 38)
                    .shadow(color: AscendTheme.gold.opacity(0.35), radius: 4)

                Image(systemName: "flame.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.black)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("知境录")
                        .font(.system(.headline, design: .serif))
                        .bold()

                    Text("Lv.\(appState.learnerLevel)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AscendTheme.gold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(AscendTheme.gold.opacity(0.18))
                        .clipShape(Capsule())
                }

                Text("总积知验 \(appState.totalXP.formatted()) XP")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: openMainWindow) {
                Image(systemName: "macwindow")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("打开知境录主窗口")
        }
    }

    // MARK: - 2. 状态条

    private var statusSection: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.isCollectionSchedulerRunning ? AscendTheme.jade : AscendTheme.slate)
                        .frame(width: 8, height: 8)
                        .shadow(color: appState.isCollectionSchedulerRunning ? AscendTheme.jade.opacity(0.6) : Color.clear, radius: 3)

                    Text(appState.isCollectionSchedulerRunning ? "自动采集中" : "自动采集已停")
                        .font(.system(.caption, design: .serif))
                        .bold()
                }

                Spacer()

                Button(appState.isCollecting ? "暂停" : "开启") {
                    appState.isCollecting.toggle()
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if appState.isAnalyzing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在悟道分析中…")
                        .font(.system(.caption2, design: .serif))
                        .foregroundStyle(AscendTheme.gold)
                    Spacer()
                }
                .padding(6)
                .background(AscendTheme.gold.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if appState.pendingActivityCount > 0 || appState.pendingReviewCount > 0 || appState.dueReviewCount > 0 {
                HStack {
                    if appState.pendingActivityCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundStyle(AscendTheme.amber)
                            Text("\(appState.pendingActivityCount) 条实据待析")
                                .font(.system(.caption2, design: .serif))
                        }
                    }
                    Spacer()
                    if appState.pendingReviewCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(AscendTheme.amber)
                            Text("\(appState.pendingReviewCount) 条真意待定")
                                .font(.system(.caption2, design: .serif))
                        }
                    }
                    if appState.dueReviewCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(AscendTheme.amber)
                            Text("今日复习 \(appState.dueReviewCount)")
                                .font(.system(.caption2, design: .serif))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
        }
    }

    // MARK: - 首席灵根卡片

    private func realmProgressCard(domain: DomainProgressSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("首席灵根 · \(domain.name)")
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(.secondary)
                Spacer()
                CelestialBadge(
                    title: domain.realm.title,
                    subtitle: "\(Int(domain.currentScore.rounded())) 分",
                    style: domain.currentScore >= 60 ? .gold : .jade
                )
                .scaleEffect(0.9)
            }

            // 掌握度进度条
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 5)
                    Capsule()
                        .fill(AscendTheme.jadeGradient)
                        .frame(width: max(3, proxy.size.width * CGFloat(min(1.0, domain.currentScore / 100.0))), height: 5)
                }
            }
            .frame(height: 5)

            HStack {
                Text("\(domain.knowledgeCount) 个已知知窍")
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(domain.xp) XP")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(AscendTheme.gold)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
        }
    }

    // MARK: - 今日精进

    private var todayGainsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(AscendTheme.gold)
                    Text("今日精进")
                        .font(.system(.caption, design: .serif))
                        .bold()
                }

                Spacer()

                Text("+\(todayTotalXP) XP")
                    .font(.system(.caption, design: .rounded))
                    .bold()
                    .foregroundStyle(todayTotalXP > 0 ? AscendTheme.gold : .secondary)
            }

            if appState.todayMasteryChanges.isEmpty && todayTotalXP == 0 {
                Text("今日暂无实据研习。写下代码或笔记后即刻汇聚知验。")
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 1)
            } else {
                VStack(spacing: 4) {
                    ForEach(appState.todayMasteryChanges.prefix(2)) { change in
                        HStack {
                            Text(change.title)
                                .font(.system(.caption2, design: .serif))
                                .lineLimit(1)
                            Spacer()
                            HStack(spacing: 2) {
                                Text("\(change.previous)")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.tertiary)
                                Text("\(change.current)")
                                    .bold()
                                    .foregroundStyle(AscendTheme.jade)
                            }
                            .font(.system(.caption2, design: .rounded))
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
        }
    }

    // MARK: - 急需温故卡片

    private func forgettingRecallCard(projection: ForgettingProjection) -> some View {
        Button(action: { openNode(projection.node) }) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AscendTheme.amber.opacity(0.15))
                        .frame(width: 26, height: 26)
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption2.bold())
                        .foregroundStyle(AscendTheme.amber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("急需温故")
                            .font(.system(.caption2, design: .serif))
                            .bold()
                            .foregroundStyle(AscendTheme.amber)
                        Spacer()
                        Text("衰减 -\(projection.scoreLoss) 分")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(AscendTheme.amber)
                    }

                    Text(projection.node.name)
                        .font(.system(.caption, design: .serif))
                        .bold()
                        .lineLimit(1)
                }
            }
            .padding(8)
            .background(AscendTheme.amber.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(AscendTheme.amber.opacity(0.25), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底部操作区

    private var footerActionsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("打开知境录", systemImage: "macwindow", action: openMainWindow)
                    .buttonStyle(.borderedProminent)

                Spacer()

                Button("退出知境录", systemImage: "power", action: quit)
                    .buttonStyle(.bordered)
            }

            HStack(spacing: 6) {
                Button(action: scanNow) {
                    Label(isScanning ? "巡察中…" : "巡察", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isScanning || appState.isAnalyzing)

                Button(action: runAnalysis) {
                    Label("悟道", systemImage: "sparkles")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.gold)
                .controlSize(.small)
                .disabled(appState.isAnalyzing)

                Spacer()

                Menu {
                    if !appState.endpointProfiles.isEmpty {
                        Section("当前 AI 灵犀模型") {
                            ForEach(appState.endpointProfiles) { profile in
                                ForEach(profile.cachedModelIDs, id: \.self) { modelID in
                                    Button(modelID) {
                                        appState.selectModel(profileID: profile.id, modelID: modelID)
                                    }
                                }
                            }
                        }
                        Divider()
                    }
                    TargetedSettingsButton(section: .general) {
                        Label("设置 (⌘,)", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
        }
    }

    // MARK: - 交互动作

    private func openMainWindow() {
        openWindow(id: "main")
        dismiss()
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func openNode(_ node: KnowledgeNode) {
        appState.selectedKnowledgeNodeID = node.id
        appState.selectedSection = .knowledge
        openMainWindow()
    }

    private func scanNow() {
        isScanning = true
        Task {
            try? await appState.scanSources()
            isScanning = false
        }
    }

    private func runAnalysis() {
        Task {
            await appState.runAnalysis()
        }
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
