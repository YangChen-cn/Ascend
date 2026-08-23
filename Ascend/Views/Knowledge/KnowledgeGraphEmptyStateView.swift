import SwiftUI

struct KnowledgeGraphEmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "知识图谱尚未成形",
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text("连接真实学习来源，首次分析后会自动生成知识点、知脉与掌握境界。")
            )
            HStack(spacing: 12) {
                SettingsLink {
                    Label("添加数据源", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
                Button("立即分析", systemImage: "sparkles", action: analyze)
                    .disabled(appState.isAnalyzing)
            }
            Divider()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                OnboardingStepView(number: 1, title: "采集", detail: "连接 Git 仓库或 Markdown 目录", systemImage: "externaldrive")
                OnboardingStepView(number: 2, title: "辨识", detail: "AI 提取知识点并提出知脉关系", systemImage: "sparkles")
                OnboardingStepView(number: 3, title: "积累", detail: "验证证据后更新掌握与境界", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .panelCard()
    }

    private func analyze() {
        Task { await appState.runAnalysis() }
    }
}
