import SwiftUI

struct MenuBarRealmSummary: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    private var leadingDomain: DomainProgressSnapshot? {
        appState.domainProgress.first
    }

    var body: some View {
        Group {
            if let domain = leadingDomain, appState.totalXP > 0 {
                Button(action: openAbilitiesMap) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center) {
                            HStack(spacing: 5) {
                                Image(systemName: "seal.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AscendTheme.gold)
                                Text("首席灵根 · \(domain.name)")
                                    .font(.system(size: 11, weight: .semibold, design: .serif))
                            }

                            Spacer()

                            CelestialBadge(
                                title: domain.realm.title,
                                subtitle: "\(Int(domain.currentScore.rounded())) 分",
                                style: domain.currentScore >= 60 ? .gold : .jade
                            )
                            .scaleEffect(0.85)
                        }

                        // 掌握度与 XP 进度条
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(AscendTheme.jadeGradient)
                                    .frame(
                                        width: max(4, proxy.size.width * CGFloat(min(1.0, domain.currentScore / 100.0))),
                                        height: 4
                                    )
                            }
                        }
                        .frame(height: 4)

                        HStack {
                            Text("\(domain.knowledgeCount) 个已悟知识点")
                                .font(.system(size: 9.5, design: .serif))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(domain.xp) XP")
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundStyle(AscendTheme.gold)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
                .help("点击打开能力地图与领域详情")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func openAbilitiesMap() {
        appState.selectedSection = .abilities
        openWindow(id: "main")
        dismiss()
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
