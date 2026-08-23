import SwiftUI

struct MenuBarDashboardContent: View {
    @Environment(\.colorScheme) private var colorScheme

    let hasAttentionItems: Bool
    let hasActiveDomain: Bool
    @Binding var isReviewSheetPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            MenuBarTodaySummary()

            Divider()
                .overlay(MenuBarPalette.divider(colorScheme))

            MenuBarNavigationGrid(isReviewSheetPresented: $isReviewSheetPresented)

            if hasAttentionItems {
                Divider()
                    .overlay(MenuBarPalette.divider(colorScheme))
                MenuBarAttentionSection(isReviewSheetPresented: $isReviewSheetPresented)
            }

            if hasActiveDomain {
                Divider()
                    .overlay(MenuBarPalette.divider(colorScheme))
                MenuBarRealmSummary()
            }

            Divider()
                .overlay(MenuBarPalette.divider(colorScheme))

            MenuBarSourceHealth()
        }
    }
}
