import SwiftUI

struct ChallengeEmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AscendTheme.amber.opacity(0.12))
                        .frame(width: 54, height: 54)
                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundStyle(AscendTheme.amber)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(AscendTheme.isXuanqing ? "修真试炼令 · 虚席以待" : "尚无可验证挑战")
                        .font(.system(.title3, design: AscendTheme.titleDesign))
                        .bold()
                    Text("积累项目、练习或独立解决实据后，AI 会针对薄弱知识点与下一境门槛自动推演并颁布试炼令。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }

            HStack(spacing: 12) {
                TargetedSettingsButton(section: .sources) {
                    Label("配置学习来源", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)

                Button("周天巡察实据", systemImage: "sparkles", action: analyze)
                    .buttonStyle(.bordered)
                    .disabled(appState.isAnalyzing)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func analyze() {
        Task { await appState.runAnalysis() }
    }
}
