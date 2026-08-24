import SwiftUI

struct AppPageScaffold<Content: View>: View {
    @ViewBuilder let content: Content
    var showsLandscape: Bool = true

    init(showsLandscape: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsLandscape = showsLandscape
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FeaturePageBackground()

            if showsLandscape {
                InkLandscapeWatermark(height: 112, opacity: 0.34)
                    .frame(maxWidth: 720)
                    .opacity(AscendTheme.isXuanqing ? 1 : 0)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AscendTheme.Spacing.section) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AscendTheme.pageHorizontalPadding)
                .padding(.vertical, AscendTheme.pageVerticalPadding)
            }
            .scrollContentBackground(.visible)
        }
    }
}
