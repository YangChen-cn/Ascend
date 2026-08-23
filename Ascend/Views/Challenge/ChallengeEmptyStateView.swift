import SwiftUI

struct ChallengeEmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 18) {
            ContentUnavailableView(
                "尚无可验证挑战",
                systemImage: "flag.checkered",
                description: Text("积累项目、练习或独立解决证据后，AI 会针对薄弱知识与下一境推荐挑战。")
            )
            HStack {
                SettingsLink {
                    Label("配置学习来源", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
                Button("检查新证据", systemImage: "sparkles", action: analyze)
                    .disabled(appState.isAnalyzing)
            }
        }
        .frame(maxWidth: .infinity)
        .panelCard()
    }

    private func analyze() {
        Task { await appState.runAnalysis() }
    }
}
