import SwiftUI

struct KnowledgeGraphEmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AscendTheme.gold.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.title)
                        .foregroundStyle(AscendTheme.gold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(AscendTheme.isXuanqing ? "周天星图尚未成形 · 虚位以待" : "知识图谱尚未成形")
                        .font(.system(.title2, design: AscendTheme.titleDesign))
                        .bold()
                    Text("连接真实研习来源并完成首次悟道分析后，系统会自动提炼知识点、贯通灵脉与掌握境界。")
                        .font(.system(.callout, design: AscendTheme.titleDesign))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }
            .padding(.vertical, 8)

            HStack(spacing: 14) {
                SettingsLink {
                    Label("配置研习数据源", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)

                Button("启行悟道分析", systemImage: "sparkles", action: analyze)
                    .buttonStyle(.bordered)
                    .disabled(appState.isAnalyzing)
            }

            Divider()
                .overlay(AscendTheme.gold.opacity(0.15))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                OnboardingStepView(number: 1, title: "研习采集", detail: "连接 Git 仓库或 Markdown 目录", systemImage: "externaldrive")
                OnboardingStepView(number: 2, title: "AI 辨析", detail: "提取细粒度知识点并建议知脉关系", systemImage: "sparkles")
                OnboardingStepView(number: 3, title: "道业积累", detail: "验证实据后实时更新掌握度与境界", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .panelCard()
    }

    private func analyze() {
        Task { await appState.runAnalysis() }
    }
}
