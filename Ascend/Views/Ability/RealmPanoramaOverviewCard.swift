import SwiftUI

/// 「诸天道纪 · 六大境界全景概览卡」
/// 宏观展示用户在六大境界（初窥、入门、通晓、融会、化用、通达）的知窍修业分布、知验积蓄与周天灵机。
/// 在领域较少或宽屏窗口展开时，作为宏观修行画卷展示，丰富视觉层次与东方修道沉浸感。
struct RealmPanoramaOverviewCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var realmDistribution: [(realm: DomainRealm, count: Int)] {
        let allRealms = DomainRealm.allCases.filter { $0 != .unstarted }
        let nodeCountsByRealm: [DomainRealm: Int] = appState.knowledgeNodes.reduce(into: [:]) { counts, node in
            let stage = appState.mastery(for: node.id)?.highestStage ?? .entry
            let realm: DomainRealm = switch stage {
            case .entry: .apprentice
            case .advancing: .entry
            case .proficient: .advancing
            case .integrated: .refining
            case .connected: .connected
            case .mastered: .transformed
            }
            counts[realm, default: 0] += 1
        }

        return allRealms.map { realm in
            (realm: realm, count: nodeCountsByRealm[realm, default: 0])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 头部标题与朱砂印
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundStyle(AscendTheme.gold)
                    Text(AscendTheme.isXuanqing ? "诸天道纪 · 诸境全览" : "境界全局概览")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()
                }

                Spacer()

                ClassicalSealMark(text: "道纪", shape: .square, style: .cinnabar, carving: .intaglio, size: 24)
            }

            // 统计总览条带
            HStack(spacing: 12) {
                statTile(title: "已知知窍", value: "\(appState.knowledgeNodes.count)", icon: "point.3.filled.connected.trianglepath.dotted", color: AscendTheme.jade)
                statTile(title: "总积知验", value: "\(appState.totalXP.formatted()) XP", icon: "flame.fill", color: AscendTheme.gold)
                statTile(title: "主修领域", value: appState.domainProgress.first?.name ?? "诸天归藏", icon: "mountain.2.fill", color: AscendTheme.cobalt)
            }

            Divider()
                .overlay(AscendTheme.separator(for: colorScheme))

            // 六境节点梯次分布条带
            VStack(alignment: .leading, spacing: 8) {
                Text("知窍修业阶梯分布")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                    ForEach(realmDistribution, id: \.realm.rawValue) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color(for: item.realm))
                                .frame(width: 8, height: 8)
                            Text(item.realm.title)
                                .font(.caption2)
                                .bold()
                            Spacer()
                            Text("\(item.count)")
                                .font(.system(.caption2, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(item.count > 0 ? Color.primary : .secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                    }
                }
            }
        }
        .panelCard()
    }

    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
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

    private func color(for realm: DomainRealm) -> Color {
        switch realm {
        case .transformed, .connected: AscendTheme.gold
        case .refining: AscendTheme.jade
        case .advancing: AscendTheme.cobalt
        case .entry, .apprentice, .unstarted: AscendTheme.slate
        }
    }
}
