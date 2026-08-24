import SwiftUI

/// 「太虚研经 · 破境演武心诀卡」
/// 专属于「修炼挑战」界面的古风指引研经卡。
/// 当试炼令较少或处于空态时，优雅充实界面，阐述以真实实作破境修业的演武法度。
struct ChallengeCodexCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 头部标题与泥金印
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flag.2.crossed.fill")
                        .foregroundStyle(AscendTheme.gold)
                    Text(AscendTheme.isXuanqing ? "太虚研经 · 破境演武心诀" : "实战破境指引")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()
                }

                Spacer()

                ClassicalSealMark(text: "演武", shape: .square, style: .gold, carving: .intaglio, size: 22)
            }

            Text("以真实工程实作突破境界瓶颈。试炼令由系统根据当前知窍薄弱处动态推演生成，非凭空虚构。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            Divider()
                .overlay(AscendTheme.separator(for: colorScheme))

            // 三大破境法门
            VStack(alignment: .leading, spacing: 10) {
                codexItem(
                    index: "壹",
                    title: "真火实炼 · 生产实据",
                    detail: "融会以上之进阶，必须依赖本地真实代码改动与独立解决实据，方可正式叩关。"
                )
                codexItem(
                    index: "贰",
                    title: "知行合一 · 自动鉴核",
                    detail: "无需人工打卡，当采集到符合试炼条件的提交或笔记时，系统周天巡察将自动印证功成。"
                )
                codexItem(
                    index: "叁",
                    title: "循序渐进 · 独立解题",
                    detail: "初窥与入门重在日常积累；高阶境界则须在无 AI 辅助下独立攻克，方得化用通达。"
                )
            }
        }
        .panelCard()
    }

    private func codexItem(index: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.system(.caption, design: .serif))
                .bold()
                .foregroundStyle(AscendTheme.gold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AscendTheme.gold.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: AscendTheme.titleDesign))
                    .bold()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
    }
}
