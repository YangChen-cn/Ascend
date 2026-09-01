import SwiftUI

struct DomainProgressCardView: View {
    let domain: DomainProgressSnapshot
    let manage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(domain.name)
                        .font(.system(.title2, design: .serif))
                        .bold()
                    Text("\(domain.knowledgeCount) 个知识点 · \(domain.masterySampleSummary) · \(domain.xp.formatted()) XP")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ClassicalSealMark(
                    text: domain.realm.title,
                    shape: .square,
                    style: domain.realm == .transformed || domain.realm == .connected ? .gold : .cinnabar,
                    carving: .intaglio,
                    size: 24
                )
                DomainAssessmentLaunchButton(domainName: domain.name)
                Button("管理", systemImage: "ellipsis.circle", action: manage)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("重命名、合并或删除“\(domain.name)”")
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(domain.score.rounded()))")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(AscendTheme.gold)
                    Text("分 · 当前掌握度")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let next = domain.nextRealm {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AscendTheme.gold)
                        Text("下一境 · \(next.title)")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(Color.primary.opacity(0.85))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AscendTheme.gold.opacity(0.10))
                    .clipShape(Capsule())
                }
            }

            if domain.currentRealm != domain.realm {
                Label(
                    "历史掌握 \(Int(domain.historicalScore.rounded())) · 当前境况 \(domain.currentRealm.title)",
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            // 灵力进度条
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 7)

                    Capsule()
                        .fill(AscendTheme.jadeGradient)
                    .frame(width: max(8, proxy.size.width * CGFloat(domain.advancementProgress)), height: 7)
                }
            }
            .frame(height: 7)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("知验进度")
            .accessibilityValue(
                domain.nextRealmGateSummary ?? "已达最高境界"
            )

            if let next = domain.nextRealm {
                HStack {
                    Label("要求掌握 ≥ \(Int(next.minimumScore))", systemImage: "gauge.with.dots.needle.33percent")
                    Spacer()
                    Label(
                        "\(domain.xp.formatted()) / \(next.minimumXP.formatted()) XP",
                        systemImage: "flame"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AscendTheme.gold)
                    Text("此道已臻大圆满·通达天人")
                        .font(.caption)
                        .foregroundStyle(AscendTheme.gold)
                }
            }
        }
        .panelCard(highlighted: domain.realm == .transformed || domain.realm == .connected)
    }
}
