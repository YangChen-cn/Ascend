import SwiftUI

/// 「万象归藏 · 格物致知流转鉴」
/// 专属于「资料流」界面的古风流转鉴卡。
/// 当资料流较短或初入道途时，优雅充实界面，阐述本地文件与 Git 提交如何溯源淬炼为真实知行实据。
struct EvidenceArchivalCompassCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 头部标题与朱砂印
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(AscendTheme.jade)
                    Text(AscendTheme.isXuanqing ? "万象归藏 · 格物致知流转鉴" : "学习资料流转法度")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()
                }

                Spacer()

                ClassicalSealMark(text: "归藏", shape: .square, style: .cinnabar, carving: .intaglio, size: 22)
            }

            Text("行之力则知愈进，知之深则行愈达。所有成长必须由本地真实研习证据驱动，绝无凭空捏造。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            // 源流状态条带
            HStack(spacing: 12) {
                sourceStatTile(
                    title: "研习源流",
                    value: "\(appState.sources.count) 处",
                    icon: "externaldrive.fill",
                    color: AscendTheme.jade
                )
                sourceStatTile(
                    title: "已集实据",
                    value: "\(appState.totalActivityCount) 卷",
                    icon: "doc.text.fill",
                    color: AscendTheme.gold
                )
                sourceStatTile(
                    title: "巡察状态",
                    value: appState.isCollecting ? "灵机巡察中" : "安歇待发",
                    icon: "sparkles",
                    color: appState.isCollecting ? AscendTheme.jade : AscendTheme.slate
                )
            }

            Divider()
                .overlay(AscendTheme.separator(for: colorScheme))

            // 三大归藏法度
            VStack(alignment: .leading, spacing: 10) {
                ruleRow(
                    index: "源",
                    title: "双流并蓄 · 笔记与实作",
                    detail: "Markdown 笔记侧重概念理解与修正；Git 代码提交侧重工程实践与独立排障。"
                )
                ruleRow(
                    index: "鉴",
                    title: "指纹去重 · 规范归经",
                    detail: "依据内容哈希与知窍指纹严格去重，同类改动绝不重复计分，确保知验纯正真实。"
                )
                ruleRow(
                    index: "安",
                    title: "本地优先 · 私隐守正",
                    detail: "所有源码与笔记仅在本地分析，API Key 严格存于 Keychain，绝无数据云端泄露。"
                )
            }
        }
        .panelCard()
    }

    private func sourceStatTile(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.subheadline, design: .rounded))
                    .bold()
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.06))
        )
    }

    private func ruleRow(index: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.system(.caption, design: .serif))
                .bold()
                .foregroundStyle(AscendTheme.jade)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AscendTheme.jade.opacity(0.10))
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
