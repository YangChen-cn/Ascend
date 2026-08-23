import SwiftUI

struct EvidenceTimelineView: View {
    @Environment(AppState.self) private var appState

    private var todayEvents: [ActivityEvent] {
        appState.activityEvents.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .foregroundStyle(AscendTheme.cobalt)
                    Text("今日研习 · 证道实据")
                        .font(.system(.headline, design: .serif))
                        .bold()
                }
                Spacer()
                if !todayEvents.isEmpty {
                    CelestialBadge(
                        title: "\(todayEvents.count) 条实据",
                        style: .astral
                    )
                }
            }

            if appState.activityEvents.isEmpty {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AscendTheme.cobalt.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(AscendTheme.cobalt)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("玉简清白 · 尚未落墨")
                            .font(.system(.body, design: .serif))
                            .bold()
                        Text("连接 Git 代码仓库或 Markdown 笔记目录，一毫一厘之功，皆将化为证道实据。")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }
                .padding(.vertical, 8)
            } else if todayEvents.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("今日尚未采集到新活动")
                            .font(.system(.body, design: .serif))
                            .bold()
                        Text("已有 \(appState.activityEvents.count) 条历史活动。新的代码提交或笔记将按时在此汇聚。")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } else {
                ForEach(todayEvents.prefix(5)) { event in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: event.sourceKindRawValue))
                            .foregroundStyle(color(for: event.sourceKindRawValue))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(.callout, design: .serif))
                                .bold()
                            Text(event.summary)
                                .font(.system(.caption, design: .serif))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(event.timestamp, format: .dateTime.hour().minute())
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    if event.id != todayEvents.prefix(5).last?.id {
                        Divider()
                            .overlay(Color.primary.opacity(0.06))
                    }
                }
            }
        }
    }

    private func icon(for rawValue: String) -> String {
        switch SourceKind(rawValue: rawValue) {
        case .gitRepository: "arrow.triangle.branch"
        case .markdownDirectory: "doc.text"
        case .remoteGitMarkdown: "icloud.and.arrow.down"
        case .manual, .none: "checkmark.circle"
        }
    }

    private func color(for rawValue: String) -> Color {
        switch SourceKind(rawValue: rawValue) {
        case .gitRepository: .orange
        case .markdownDirectory: .purple
        case .remoteGitMarkdown: .blue
        case .manual, .none: AscendTheme.jade
        }
    }
}
