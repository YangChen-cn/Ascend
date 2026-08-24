import SwiftUI

struct AbilityEmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AscendTheme.jade.opacity(0.12))
                        .frame(width: 54, height: 54)
                    Image(systemName: "mountain.2.fill")
                        .font(.title2)
                        .foregroundStyle(AscendTheme.jade)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(AscendTheme.isXuanqing ? "尚未凝聚领域灵根 · 待起法舟" : "尚未形成领域")
                            .font(.system(.title3, design: AscendTheme.titleDesign))
                            .bold()
                        if AscendTheme.isXuanqing {
                            ClassicalSealMark(text: "待起", shape: .square, style: .cinnabar, carving: .intaglio, size: 22)
                        }
                    }
                    Text("当 AI 从真实学习实据中辨识出知识点后，会自动归入各专业领域，并独立计算境界与知验。")
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

                Button("启行悟道分析", systemImage: "sparkles", action: analyze)
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
