import SwiftUI

struct EvidenceFeedView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            FeaturePageBackground()
            VStack(alignment: .leading, spacing: 20) {
                PageHeaderView(
                    "资料流",
                    subtitle: "每一次评分变化，都能回到原始活动与 AI 判断。",
                    systemImage: "list.bullet.rectangle"
                )
                if appState.activityEvents.isEmpty {
                    VStack(spacing: 18) {
                        ContentUnavailableView(
                            "资料流为空",
                            systemImage: "tray",
                            description: Text("添加学习来源后，采集到的提交、笔记与练习会按时间汇聚在这里。")
                        )
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                            OnboardingStepView(number: 1, title: "连接来源", detail: "选择 Git 仓库或 Markdown 目录", systemImage: "externaldrive.badge.plus")
                            OnboardingStepView(number: 2, title: "最小采集", detail: "仅保留定位、摘要与有限审计片段", systemImage: "lock.shield")
                            OnboardingStepView(number: 3, title: "等待分析", detail: "验证后才写入证据与评分账本", systemImage: "checkmark.seal")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .panelCard()
                } else {
                    Table(appState.activityEvents) {
                        TableColumn("时间") { event in
                            Text(event.timestamp, format: .dateTime.month().day().hour().minute())
                        }
                        TableColumn("来源") { event in
                            Text(SourceKind(rawValue: event.sourceKindRawValue)?.title ?? "未知")
                        }
                        TableColumn("活动") { event in
                            VStack(alignment: .leading) {
                                Text(event.title).bold()
                                Text(event.summary).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        TableColumn("状态") { event in
                            Label(event.isProcessed ? "已分析" : "待分析", systemImage: event.isProcessed ? "checkmark.circle.fill" : "clock")
                                .foregroundStyle(event.isProcessed ? AscendTheme.jade : AscendTheme.amber)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.secondary.opacity(0.16), lineWidth: 1)
                    }
                }
            }
            .frame(maxWidth: 1_280, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
    }
}
