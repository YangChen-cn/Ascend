import SwiftUI

struct MenuBarSourceHealth: View {
    @Environment(AppState.self) private var appState

    private var healthItems: [MenuBarHealthItem] {
        [
            sourceHealth(
                id: "local-markdown",
                title: "本地 Markdown",
                kinds: [.markdownDirectory]
            ),
            sourceHealth(
                id: "remote-git",
                title: "Remote Git",
                kinds: [.remoteGitRepository, .remoteGitMarkdown, .gitRepository]
            ),
            aiHealth
        ]
    }

    var body: some View {
        let items = healthItems
        let firstWarning = items.first { $0.state == .warning }

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: symbol(for: item.state))
                                .font(.caption)
                                .foregroundStyle(color(for: item.state))
                            Text(item.title)
                                .font(.caption)
                                .lineLimit(1)
                        }

                        Text(item.status)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(item.state == .warning ? AscendTheme.amber : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(item.detail ?? item.status)
                }
            }

            if let warning = firstWarning {
                Label(warning.detail ?? "\(warning.title) 状态异常", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(AscendTheme.amber)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private func sourceHealth(
        id: String,
        title: String,
        kinds: Set<SourceKind>
    ) -> MenuBarHealthItem {
        let configured = appState.sources.filter { kinds.contains($0.kind) }
        let enabled = configured.filter(\.isEnabled)
        if enabled.isEmpty {
            return MenuBarHealthItem(
                id: id,
                title: title,
                status: configured.isEmpty ? "未配置" : "已暂停",
                state: .inactive,
                detail: nil
            )
        }
        if let failed = enabled.first(where: { $0.lastSyncError != nil }) {
            return MenuBarHealthItem(
                id: id,
                title: title,
                status: "同步失败",
                state: .warning,
                detail: failed.lastSyncError
            )
        }
        if appState.isScanningSources {
            return MenuBarHealthItem(id: id, title: title, status: "巡察中", state: .healthy, detail: nil)
        }
        if !appState.isCollectionSchedulerRunning {
            return MenuBarHealthItem(id: id, title: title, status: "采集已暂停", state: .inactive, detail: nil)
        }
        let lastScannedAt = enabled.compactMap(\.lastScannedAt).max()
        return MenuBarHealthItem(
            id: id,
            title: title,
            status: relativeStatus(for: lastScannedAt),
            state: .healthy,
            detail: nil
        )
    }

    private var aiHealth: MenuBarHealthItem {
        guard let endpoint = appState.activeEndpoint ?? appState.endpointProfiles.first(where: \.isEnabled) else {
            return MenuBarHealthItem(id: "ai", title: "AI", status: "未配置", state: .inactive, detail: nil)
        }
        if let error = endpoint.lastError, !error.isEmpty {
            return MenuBarHealthItem(id: "ai", title: "AI", status: "连接异常", state: .warning, detail: error)
        }
        if endpoint.selectedModelID.isEmpty {
            return MenuBarHealthItem(id: "ai", title: "AI", status: "待选模型", state: .inactive, detail: endpoint.name)
        }
        return MenuBarHealthItem(id: "ai", title: "AI", status: "就绪", state: .healthy, detail: endpoint.selectedModelID)
    }

    private func relativeStatus(for date: Date?) -> String {
        guard let date else { return "等待首次巡察" }
        let seconds = max(0, Date.now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "刚刚"
        case ..<3_600: return "\(Int(seconds / 60)) 分钟前"
        case ..<86_400: return "\(Int(seconds / 3_600)) 小时前"
        default: return date.formatted(.dateTime.month().day())
        }
    }

    private func symbol(for state: MenuBarHealthItem.State) -> String {
        switch state {
        case .healthy: "circle.fill"
        case .inactive: "circle"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    private func color(for state: MenuBarHealthItem.State) -> Color {
        switch state {
        case .healthy: AscendTheme.jade
        case .inactive: .secondary
        case .warning: AscendTheme.amber
        }
    }
}
