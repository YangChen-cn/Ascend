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
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()
                }
                Spacer()
                TargetedSettingsButton(section: .sources) {
                    CelestialBadge(title: "初入道途", style: .jade)
                }
                .buttonStyle(.plain)
            }

            Text("万法由心，行而后知。只需三步，即可开启私人本地优先的修真知境监控：")
                .font(.system(.caption, design: AscendTheme.titleDesign))
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 10) {
                TargetedSettingsButton(section: .sources) {
                    guideStepContent(
                        num: "壹",
                        title: "连接研习来源",
                        desc: "选择 Git 代码仓库或 Markdown 笔记目录",
                        isDone: !appState.sources.isEmpty
                    )
                }
                .buttonStyle(.plain)

                TargetedSettingsButton(section: .ai) {
                    guideStepContent(
                        num: "贰",
                        title: "配置大模型",
                        desc: "填入 OpenAI 兼容端点与 API Key",
                        isDone: appState.activeEndpoint != nil
                    )
                }
                .buttonStyle(.plain)

                Button(action: { Task { await appState.runAnalysis() } }) {
                    guideStepContent(
                        num: "叁",
                        title: "启行周天悟道",
                        desc: "点击右上角悟道分析，生成掌握度与星图",
                        isDone: !appState.knowledgeNodes.isEmpty
                    )
                }
                .buttonStyle(.plain)
            }

            Text("此后无需刻意做题：日常读文档、写代码，知境录会在后台理解并推动初窥 → 入门 → 通晓；答题只是可选的加速器。")
                .font(.system(.caption2, design: AscendTheme.titleDesign))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AscendTheme.gold.opacity(0.06))
                )
        }
    }

    private func guideStepContent(num: String, title: String, desc: String, isDone: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(isDone ? AscendTheme.jade.opacity(0.18) : Color.primary.opacity(0.06))
                    .frame(width: 22, height: 22)
                Text(num)
                    .font(.system(.caption2, design: AscendTheme.titleDesign))
                    .bold()
                    .foregroundStyle(isDone ? AscendTheme.jade : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(.callout, design: AscendTheme.titleDesign))
                        .bold()
                        .foregroundStyle(isDone ? .primary : .secondary)
                    if isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AscendTheme.jade)
                    } else {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption2)
                            .foregroundStyle(AscendTheme.gold.opacity(0.8))
                    }
                }
                Text(desc)
                    .font(.system(.caption2, design: AscendTheme.titleDesign))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.015))
        )
    }
}
