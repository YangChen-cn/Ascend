import SwiftUI

struct ForgettingListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitleView("正在遗忘", systemImage: "clock.badge.exclamationmark")
                .foregroundStyle(AscendTheme.amber)
            if appState.forgettingProjections.isEmpty {
                Text("暂无需要巩固的知识点")
                    .foregroundStyle(.secondary)
            }
            ForEach(appState.forgettingProjections.prefix(4)) { item in
                HStack {
                    Text(item.node.name)
                    Spacer()
                    Text("-\(item.scoreLoss)")
                        .bold()
                        .foregroundStyle(AscendTheme.amber)
                }
                ProgressView(value: item.retention, total: 100)
                    .tint(AscendTheme.amber)
            }
        }
    }
}
