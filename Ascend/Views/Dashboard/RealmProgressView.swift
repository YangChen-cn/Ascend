import SwiftUI

struct RealmProgressView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "mountain.2.fill")
                        .foregroundStyle(AscendTheme.gold)
                    Text("诸天境界 · 灵根化境")
                        .font(.system(.headline, design: .serif))
                        .bold()
                }
                Spacer()
                if !appState.domainProgress.isEmpty {
                    Text("\(appState.domainProgress.count) 领域")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.secondary)
                }
            }

            if appState.domainProgress.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "seal")
                        .font(.title3)
                        .foregroundStyle(AscendTheme.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("灵根初生 · 虚位以待")
                            .font(.system(.subheadline, design: .serif))
                            .bold()
                        Text("知识点归入各领域后，各域将独立运转掌握度、知验与六重境界。")
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                ForEach(appState.domainProgress.prefix(3)) { domain in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(domain.name)
                                .font(.system(.callout, design: .serif))
                                .bold()
                            Spacer()
                            CelestialBadge(
                                title: "最高 · \(domain.realm.title)",
                                style: domain.realm == .transformed || domain.realm == .connected ? .gold : .jade
                            )
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 5)
                                Capsule()
                                    .fill(AscendTheme.jadeGradient)
                                    .frame(width: max(4, proxy.size.width * CGFloat(min(1.0, max(0.0, domain.xpProgress)))), height: 5)
                            }
                        }
                        .frame(height: 5)

                        HStack {
                            Text("\(domain.xp.formatted()) XP")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(AscendTheme.gold)
                            Spacer()
                            if let next = domain.nextRealm {
                                Text("破境需 \(next.minimumXP.formatted()) XP")
                                    .font(.system(.caption2, design: .serif))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if domain.currentRealm != domain.realm {
                            Text("当前境况 · \(domain.currentRealm.title)（记忆保持已投影）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
