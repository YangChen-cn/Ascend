import SwiftUI

struct FeaturePageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AscendTheme.background(for: colorScheme)

            if AscendTheme.isXuanqing {
                if colorScheme == .dark {
                    RadialGradient(
                        colors: [
                            Color(red: 0.05, green: 0.25, blue: 0.22).opacity(0.20),
                            Color(red: 0.10, green: 0.13, blue: 0.12).opacity(0.10),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 80,
                        endRadius: 750
                    )

                    RadialGradient(
                        colors: [
                            Color(red: 0.66, green: 0.43, blue: 0.12).opacity(0.08),
                            Color(red: 0.05, green: 0.20, blue: 0.22).opacity(0.10),
                            .clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 100,
                        endRadius: 800
                    )
                } else {
                    RadialGradient(
                        colors: [
                            Color(red: 0.15, green: 0.46, blue: 0.38).opacity(0.055),
                            Color(red: 0.72, green: 0.56, blue: 0.28).opacity(0.045),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 60,
                        endRadius: 650
                    )
                }
            } else {
                if colorScheme == .dark {
                    RadialGradient(
                        colors: [
                            Color(red: 0.10, green: 0.20, blue: 0.35).opacity(0.15),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 60,
                        endRadius: 600
                    )
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.97, blue: 0.99),
                            Color(red: 0.98, green: 0.985, blue: 0.995)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
