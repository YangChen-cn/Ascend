import SwiftUI

struct RealmLadderView: View {
    private let realms = DomainRealm.allCases.filter { $0 != .unstarted }
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "mountain.2.fill")
                    .foregroundStyle(AscendTheme.gold)
                Text("问道天梯 · 六大境界")
                    .font(.system(.headline, design: .serif))
                    .bold()
            }

            Text("道法自然，循序渐进。境界须同时满足该领域的掌握度与真实知验，方能破境功成。")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(Array(realms.enumerated()), id: \.element.rawValue) { index, realm in
                    HStack(spacing: 12) {
                        // 阶梯层级指示符
                        ZStack {
                            Circle()
                                .fill(realmGradient(for: realm))
                                .frame(width: 24, height: 24)
                            Text("\(index + 1)")
                                .font(.system(.caption2, design: .rounded))
                                .bold()
                                .foregroundStyle(Color.black.opacity(0.8))
                        }

                        Text(realm.title)
                            .font(.system(.body, design: .serif))
                            .bold()
                            .frame(width: 52, alignment: .leading)

                        Text("掌握 ≥ \(Int(realm.minimumScore))")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Spacer()

                        CelestialBadge(
                            title: "\(realm.minimumXP.formatted()) XP",
                            style: badgeStyle(for: realm)
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.025))
                    )

                    if realm != realms.last {
                        HStack {
                            Spacer().frame(width: 20)
                            Rectangle()
                                .fill(AscendTheme.gold.opacity(0.18))
                                .frame(width: 2, height: 8)
                            Spacer()
                        }
                    }
                }
            }
        }
        .panelCard()
    }

    private func realmGradient(for realm: DomainRealm) -> LinearGradient {
        switch realm {
        case .transformed, .connected: AscendTheme.goldGradient
        case .refining: AscendTheme.jadeGradient
        case .advancing: AscendTheme.astralGradient
        case .entry, .apprentice, .unstarted:
            LinearGradient(colors: [AscendTheme.slate.opacity(0.6), AscendTheme.slate], startPoint: .top, endPoint: .bottom)
        }
    }

    private func badgeStyle(for realm: DomainRealm) -> CelestialBadgeStyle {
        switch realm {
        case .transformed, .connected: .gold
        case .refining: .jade
        case .advancing: .astral
        case .entry, .apprentice, .unstarted: .neutral
        }
    }
}
