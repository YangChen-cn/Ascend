import SwiftUI

struct MenuBarSourceHealth: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var healthItems: [MenuBarHealthItem] {
        [
            sourceHealth(
                id: "markdown",
                title: "Markdown",
                kinds: [.markdownDirectory]
            ),
            sourceHealth(
                id: "git",
                title: "Git",
                kinds: [.remoteGitRepository, .remoteGitMarkdown, .gitRepository]
            ),
            aiHealth
        ]
    }

    var body: some View {
        let items = healthItems
        let firstWarning = items.first { $0.state == .warning }

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    HStack(spacing: 4) {
                        Image(systemName: symbol(for: item))
                            .font(.system(size: 7))
                            .foregroundStyle(color(for: item.state))

                        Text(pillLabel(for: item))
                            .font(.system(size: 11))
                            .foregroundStyle(textColor(for: item))
                            .lineLimit(1)
                    }
                    .help(item.detail ?? "\(item.title)：\(item.status)")
                }

                Spacer(minLength: 0)
            }

            if let warning = firstWarning {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(MenuBarPalette.cinnabar(colorScheme))

                    Text(warning.detail ?? "\(warning.title) 同步失败")
                        .font(.system(size: 11))
                        .foregroundStyle(MenuBarPalette.cinnabar(colorScheme))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    private func pillLabel(for item: MenuBarHealthItem) -> String {
        if item.state == .inactive {
            return item.title
        } else {
            return "\(item.title) · \(item.status)"
        }
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
        if !appState.isCollecting || !appState.isCollectionSchedulerRunning {
            return MenuBarHealthItem(id: id, title: title, status: "已暂停", state: .inactive, detail: nil)
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
        case ..<3_600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3_600))h"
        default: return date.formatted(.dateTime.month().day())
        }
    }

    private func symbol(for item: MenuBarHealthItem) -> String {
        switch item.state {
        case .healthy:
            return item.id == "ai" ? "sparkle" : "circle.fill"
        case .inactive:
            return "circle"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    private func color(for state: MenuBarHealthItem.State) -> Color {
        switch state {
        case .healthy: MenuBarPalette.jade(colorScheme)
        case .inactive: MenuBarPalette.secondaryInk(colorScheme).opacity(0.52)
        case .warning: MenuBarPalette.cinnabar(colorScheme)
        }
    }

    private func textColor(for item: MenuBarHealthItem) -> Color {
        switch item.state {
        case .warning: MenuBarPalette.cinnabar(colorScheme)
        case .inactive: MenuBarPalette.secondaryInk(colorScheme).opacity(0.55)
        case .healthy: MenuBarPalette.secondaryInk(colorScheme)
        }
    }
}
