import AppKit
import SwiftUI

struct MenuBarRealmSummary: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var topDomains: [DomainProgressSnapshot] {
        Array(appState.domainProgress.filter { $0.xp > 0 || $0.currentScore > 0 }.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("主修")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(MenuBarPalette.ink(colorScheme))
                .padding(.horizontal, 2)

            VStack(spacing: 3) {
                ForEach(topDomains) { domain in
                    MenuBarDomainRow(domain: domain, action: openAbilitiesMap)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
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
