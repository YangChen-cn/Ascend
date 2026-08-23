import SwiftUI

struct FeaturePageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AscendTheme.background(for: colorScheme)
            LinearGradient(
                colors: [
                    AscendTheme.cobalt.opacity(colorScheme == .dark ? 0.14 : 0.055),
                    .clear,
                    AscendTheme.amber.opacity(colorScheme == .dark ? 0.04 : 0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
