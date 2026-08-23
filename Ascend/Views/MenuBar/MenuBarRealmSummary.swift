import SwiftUI

struct MenuBarRealmSummary: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    private var topDomains: ArraySlice<DomainProgressSnapshot> {
        appState.domainProgress.filter { $0.xp > 0 }.prefix(2)
    }

    var body: some View {
        Button(action: openAbilitiesMap) {
            VStack(alignment: .leading, spacing: 7) {
                Label("主修领域", systemImage: "seal.fill")
                    .font(.system(.caption, design: .serif))
                    .bold()
                    .foregroundStyle(AscendTheme.gold)

                ForEach(topDomains) { domain in
                    HStack(spacing: 8) {
                        Text(domain.name)
                            .font(.system(.caption, design: .serif))
                            .lineLimit(1)
                            .frame(width: 112, alignment: .leading)

                        Text("\(domain.currentRealm.title) · \(Int(domain.currentScore.rounded()))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 76, alignment: .trailing)

                        ProgressView(value: domain.currentScore, total: 100)
                            .progressViewStyle(.linear)
                            .tint(domain.currentScore >= 60 ? AscendTheme.gold : AscendTheme.jade)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(domain.name)，\(domain.currentRealm.title)，当前掌握 \(Int(domain.currentScore.rounded()))")
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("打开能力地图与领域详情")
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
