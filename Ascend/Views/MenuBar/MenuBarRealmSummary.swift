import SwiftUI

struct MenuBarRealmSummary: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var isHovered = false

    private var topDomains: [DomainProgressSnapshot] {
        Array(appState.domainProgress.filter { $0.xp > 0 || $0.currentScore > 0 }.prefix(2))
    }

    var body: some View {
        Button(action: openAbilitiesMap) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("主修")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 2)

                VStack(spacing: 2) {
                    ForEach(topDomains) { domain in
                        HStack(spacing: 8) {
                            Text(domain.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Text("\(domain.currentRealm.title) \(Int(domain.currentScore.rounded()))")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)

                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 48, height: 2.5)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(domain.currentScore >= 60 ? AscendTheme.gold : AscendTheme.jade)
                                        .frame(
                                            width: max(0, min(48, 48 * CGFloat(domain.currentScore / 100.0))),
                                            height: 2.5
                                        )
                                }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.03) : Color.clear)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("打开能力地图与领域详情")
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
