import SwiftUI

struct ReviewEmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AscendTheme.jade.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(AscendTheme.jade)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(AscendTheme.isXuanqing ? "灵台明澈 · 暂无到期复习" : "暂无到期复习任务")
                        .font(.system(.title3, design: AscendTheme.titleDesign))
                        .bold()
                    Text("当前所有已知知窍的记忆留存率均在健康区间。系统基于 FSRS 间隔重复算法持续推演，将在到达最佳遗忘临界点时自动安排主动检索。")
                        .font(.system(.callout, design: AscendTheme.titleDesign))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }

            HStack(spacing: 12) {
                Button {
                    appState.selectedSection = .knowledge
                } label: {
                    Label("浏览知识图谱", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)

                Button {
                    appState.selectedSection = .abilities
                } label: {
                    Label("查看能力地图", systemImage: "map")
                }
                .buttonStyle(.bordered)
            }

            Divider()
                .overlay(AscendTheme.gold.opacity(0.15))

            VStack(alignment: .leading, spacing: 12) {
                Text(AscendTheme.isXuanqing ? "温故之法 · 记忆推演机制" : "FSRS 记忆机制与复习流程")
                    .font(.system(.subheadline, design: AscendTheme.titleDesign))
                    .bold()
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                    OnboardingStepView(
                        number: 1,
                        title: "实据编码",
                        detail: "通过笔记与代码提交沉淀知窍，建立初始记忆稳定性",
                        systemImage: "doc.text.magnifyingglass"
                    )
                    OnboardingStepView(
                        number: 2,
                        title: "动态推演",
                        detail: "FSRS 随时间推演记忆衰减与可提取率（R）",
                        systemImage: "waveform.path.ecg"
                    )
                    OnboardingStepView(
                        number: 3,
                        title: "主动检索",
                        detail: "在遗忘临界点从记忆中提取作答，成倍加固长期记忆",
                        systemImage: "brain.head.profile"
                    )
                }
            }

            InkLandscapeWatermark(height: 70, opacity: 0.60)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
