import SwiftUI

struct AppPageScaffold<Content: View>: View {
    @ViewBuilder let content: Content
    var showsLandscape: Bool = false

    init(showsLandscape: Bool = false, @ViewBuilder content: () -> Content) {
        self.showsLandscape = showsLandscape
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FeaturePageBackground()

            if showsLandscape {
                InkLandscapeWatermark(height: 96, opacity: 0.18)
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
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }
}
