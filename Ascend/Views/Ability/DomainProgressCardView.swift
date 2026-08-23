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
                    Text("\(domain.knowledgeCount) 个知识点 · \(domain.xp.formatted()) XP")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CelestialBadge(
                    title: domain.realm.title,
                    systemImage: "seal.fill",
                    style: domain.realm == .transformed || domain.realm == .connected ? .gold : .jade
                )
                Button("管理", systemImage: "ellipsis.circle", action: manage)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .help("重命名、合并或删除“\(domain.name)”")
            }

            HStack(alignment: .lastTextBaseline) {
                Text(Int(domain.score.rounded()).formatted())
                    .font(.system(.largeTitle, design: .serif))
                    .bold()
                    .foregroundStyle(AscendTheme.gold)
                Text("掌握分")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if let next = domain.nextRealm {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.circle")
                            .foregroundStyle(AscendTheme.gold)
                        Text("下一境 · \(next.title)")
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 灵力进度条
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 7)

                    Capsule()
                        .fill(AscendTheme.jadeGradient)
                        .frame(width: max(8, proxy.size.width * CGFloat(min(100, max(0, domain.score))) / 100), height: 7)
                }
            }
            .frame(height: 7)

            if let next = domain.nextRealm {
                HStack {
                    Label("要求掌握 ≥ \(Int(next.minimumScore))", systemImage: "gauge.with.dots.needle.33percent")
                    Spacer()
                    Label("需达 \(next.minimumXP.formatted()) XP", systemImage: "flame")
                }
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.secondary)
            } else {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AscendTheme.gold)
                    Text("此道已臻大圆满·通达天人")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(AscendTheme.gold)
                }
            }
        }
        .panelCard(highlighted: domain.realm == .transformed || domain.realm == .connected)
    }
}
