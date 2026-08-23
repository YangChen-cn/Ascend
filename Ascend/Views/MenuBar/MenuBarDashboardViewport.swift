import SwiftUI

struct MenuBarDashboardViewport: View {
    let hasAttentionItems: Bool
    let hasActiveDomain: Bool
    @Binding var isReviewSheetPresented: Bool

    @State private var contentHeight: CGFloat = Self.maximumHeight

    private static let maximumHeight: CGFloat = 470

    var body: some View {
        ScrollView {
            MenuBarDashboardContent(
                hasAttentionItems: hasAttentionItems,
                hasActiveDomain: hasActiveDomain,
                isReviewSheetPresented: $isReviewSheetPresented
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { proxy in
                ceil(proxy.size.height)
            } action: { newHeight in
                guard newHeight > 0, abs(newHeight - contentHeight) > 0.5 else { return }
                contentHeight = newHeight
            }
        }
        .scrollIndicators(contentHeight > Self.maximumHeight ? .automatic : .hidden)
        .scrollDisabled(contentHeight <= Self.maximumHeight)
        .frame(height: min(contentHeight, Self.maximumHeight))
    }
}
