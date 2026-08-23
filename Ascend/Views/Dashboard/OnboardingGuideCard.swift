import SwiftUI

struct OnboardingGuideCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "compass.drawing")
                        .foregroundStyle(AscendTheme.gold)
                    Text("洞府接引 · 问道初启")
                        .font(.system(.headline, design: .serif))
                        .bold()
                }
                Spacer()
                CelestialBadge(title: "初入道途", style: .jade)
            }

            Text("万法由心，行而后知。只需三步，即可开启私人本地优先的修真知境监控：")
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 10) {
                guideStep(
                    num: "壹",
                    title: "连接研习来源",
                    desc: "选择 Git 代码仓库或 Markdown 笔记目录",
                    isDone: !appState.sources.isEmpty
                )

                guideStep(
                    num: "贰",
                    title: "配置大模型",
                    desc: "填入 OpenAI 兼容端点与 API Key",
                    isDone: appState.activeEndpointID != nil
                )

                guideStep(
                    num: "叁",
                    title: "启行周天悟道",
                    desc: "点击右上角悟道分析，生成掌握度与星图",
                    isDone: !appState.knowledgeNodes.isEmpty
                )
            }
        }
    }

    private func guideStep(num: String, title: String, desc: String, isDone: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(isDone ? AscendTheme.jade.opacity(0.18) : Color.primary.opacity(0.06))
                    .frame(width: 22, height: 22)
                Text(num)
                    .font(.system(.caption2, design: .serif))
                    .bold()
                    .foregroundStyle(isDone ? AscendTheme.jade : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(.callout, design: .serif))
                        .bold()
                        .foregroundStyle(isDone ? .primary : .secondary)
                    if isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AscendTheme.jade)
                    }
                }
                Text(desc)
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
