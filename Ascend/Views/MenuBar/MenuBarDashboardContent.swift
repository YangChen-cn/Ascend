import SwiftUI

struct MenuBarDashboardContent: View {
    let hasAttentionItems: Bool
    let hasActiveDomain: Bool
    @Binding var isReviewSheetPresented: Bool

    var body: some View {
        LazyVStack(spacing: 0) {
            MenuBarTodaySummary()

            Divider()

            MenuBarNavigationGrid(isReviewSheetPresented: $isReviewSheetPresented)

            if hasAttentionItems {
                Divider()
                MenuBarAttentionSection(isReviewSheetPresented: $isReviewSheetPresented)
            }

            if hasActiveDomain {
                Divider()
                MenuBarRealmSummary()
            }

            Divider()

            MenuBarSourceHealth()
        }
    }
}
