import SwiftUI

struct EvidenceTimelineView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleView("今日所学")
            if appState.activityEvents.isEmpty {
                ContentUnavailableView(
                    "还没有学习活动",
                    systemImage: "tray",
                    description: Text("添加 Git 仓库或 Markdown 目录后开始采集。")
                )
                .frame(minHeight: 150)
            }
            ForEach(appState.activityEvents.filter { Calendar.current.isDateInToday($0.timestamp) }.prefix(6)) { event in
                HStack(spacing: 14) {
                    Image(systemName: icon(for: event.sourceKindRawValue))
                        .foregroundStyle(color(for: event.sourceKindRawValue))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .bold()
                        Text(event.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(event.timestamp, format: .dateTime.hour().minute())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
                Divider()
            }
        }
    }

    private func icon(for rawValue: String) -> String {
        switch SourceKind(rawValue: rawValue) {
        case .gitRepository: "arrow.triangle.branch"
        case .markdownDirectory: "doc.text"
        case .manual, .none: "checkmark.circle"
        }
    }

    private func color(for rawValue: String) -> Color {
        switch SourceKind(rawValue: rawValue) {
        case .gitRepository: .orange
        case .markdownDirectory: .purple
        case .manual, .none: AscendTheme.jade
        }
    }
}
