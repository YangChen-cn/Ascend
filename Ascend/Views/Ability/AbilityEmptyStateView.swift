import SwiftUI

struct AbilityEmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 18) {
            ContentUnavailableView(
                "尚未形成领域",
                systemImage: "map",
                description: Text("当 AI 从真实证据中辨识出知识点后，会自动归入领域并独立计算境界。")
            )
            HStack {
                SettingsLink {
                    Label("配置学习来源", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
                Button("立即分析", systemImage: "sparkles", action: analyze)
                    .disabled(appState.isAnalyzing)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Label("领域由证据自然生长，不需要提前创建课程树。", systemImage: "leaf")
                Label("命名冲突与跨领域关系会进入待确认队列。", systemImage: "checkmark.seal")
                Label("领域之间的掌握、XP 与境界互不混算。", systemImage: "scale.3d")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .panelCard()
    }

    private func analyze() {
        Task { await appState.runAnalysis() }
    }
}
