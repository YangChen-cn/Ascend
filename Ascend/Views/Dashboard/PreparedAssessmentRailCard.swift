import SwiftUI

/// 「灵机研习 · 备考题包侧栏卡」
/// 在今日大盘右侧展示已就绪的 0-AI 嵌入式题包，供用户随时一键开启主动印证与研习，避免界面留白。
struct PreparedAssessmentRailCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var preparedDomains: [String] {
        Array(appState.preparedVerificationDomainNames.prefix(2))
    }

    var body: some View {
        if !preparedDomains.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.square.filled.on.square")
                        .foregroundStyle(AscendTheme.jade)
                    Text(AscendTheme.isXuanqing ? "灵机备考 · 主动研习" : "已备好研习题")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()

                    Spacer()

                    ClassicalSealMark(text: "备考", shape: .square, style: .jade, carving: .intaglio, size: 20)
                }

                Text("系统已在日常采集时预先生成研习题包，作答全程 0 次 AI 调用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)

                VStack(spacing: 8) {
                    ForEach(preparedDomains, id: \.self) { domainName in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(domainName)
                                    .font(.subheadline)
                                    .bold()
                                    .lineLimit(1)
                                Text("综合知窍印证 · 0 AI")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            DomainAssessmentLaunchButton(domainName: domainName, compact: true)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.025))
                        )
                    }
                }
            }
        }
    }
}
