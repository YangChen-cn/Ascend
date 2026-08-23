import SwiftUI

struct AbilityEmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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
                    Text(AscendTheme.isXuanqing ? "尚未凝聚领域灵根 · 待起法舟" : "尚未形成领域")
                        .font(.system(.title3, design: AscendTheme.titleDesign))
                        .bold()
                    Text("当 AI 从真实学习实据中辨识出知识点后，会自动归入各专业领域，并独立计算境界与知验。")
                        .font(.system(.caption, design: AscendTheme.titleDesign))
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

            Divider()
                .overlay(AscendTheme.gold.opacity(0.15))

            VStack(alignment: .leading, spacing: 10) {
                Label("领域由证据自然生长，不需要提前人工创建繁琐的课程树。", systemImage: "leaf.fill")
                    .font(.system(.caption, design: AscendTheme.titleDesign))
                Label("命名冲突与跨领域关系会自动进入待确认流程，不盲目入库。", systemImage: "checkmark.seal.fill")
                    .font(.system(.caption, design: AscendTheme.titleDesign))
                Label("每个领域拥有独立的掌握度、XP 与境界门槛，互不混算。", systemImage: "scale.3d")
                    .font(.system(.caption, design: AscendTheme.titleDesign))
            }
            .foregroundStyle(.secondary)

            // 底部中国水墨远山写意
            InkLandscapeWatermark(height: 90, opacity: 0.70)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func analyze() {
        Task { await appState.runAnalysis() }
    }
}
