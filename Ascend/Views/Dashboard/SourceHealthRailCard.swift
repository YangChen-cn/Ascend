import SwiftUI

/// 「周天源流 · 巡察与画卷速览卡」
/// 在今日大盘右下侧栏展示学习源流的实时监控状态、总知验道行以及导出画卷等快捷入口，优雅充实右栏空间。
struct SourceHealthRailCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExportSheetPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.connected.to.line.below.fill")
                    .foregroundStyle(AscendTheme.jade)
                Text(AscendTheme.isXuanqing ? "周天运化 · 源流态势" : "数据源流状态")
                    .font(.system(.headline, design: AscendTheme.titleDesign))
                    .bold()

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.isCollecting ? AscendTheme.jade : AscendTheme.slate)
                        .frame(width: 7, height: 7)
                    Text(appState.isCollecting ? "巡察中" : "待机")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // 2x2 统计指标网格
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    statBox(title: "活跃源流", value: "\(appState.sources.count) 处", icon: "folder.fill", color: AscendTheme.jade)
                    statBox(title: "累积实据", value: "\(appState.totalActivityCount) 卷", icon: "doc.fill", color: AscendTheme.gold)
                }
                HStack(spacing: 10) {
                    statBox(title: "凝聚知窍", value: "\(appState.knowledgeNodes.count) 个", icon: "point.3.filled.connected.trianglepath.dotted", color: AscendTheme.cobalt)
                    statBox(title: "周天知验", value: "\(appState.totalXP.formatted()) XP", icon: "flame.fill", color: AscendTheme.gold)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(AscendTheme.jade)
                Text("本地优先 · 证据链指纹去重守正")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            Spacer(minLength: 4)

            Divider()
                .overlay(AscendTheme.separator(for: colorScheme))

            // 快捷操作
            HStack(spacing: 10) {
                Button {
                    isExportSheetPresented = true
                } label: {
                    Label("研习长卷", systemImage: "scroll.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AscendTheme.gold)

                Button {
                    Task { await appState.runAnalysis() }
                } label: {
                    Label("启行巡察", systemImage: "sparkles")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
                .disabled(appState.isAnalyzing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $isExportSheetPresented) {
            CelestialScrollExportSheet()
        }
    }

    private func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .bold()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
    }
}
