import SwiftUI

struct FeaturePageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AscendTheme.background(for: colorScheme)

            if AscendTheme.isXuanqing {
                // 玄青道韵：太虚玄渊流转的灵气烟岚
                if colorScheme == .dark {
                    RadialGradient(
                        colors: [
                            Color(red: 0.05, green: 0.28, blue: 0.26).opacity(0.35),
                            Color(red: 0.08, green: 0.16, blue: 0.28).opacity(0.18),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 80,
                        endRadius: 750
                    )

                    RadialGradient(
                        colors: [
                            Color(red: 0.75, green: 0.50, blue: 0.12).opacity(0.12),
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
                            Color(red: 0.15, green: 0.55, blue: 0.45).opacity(0.08),
                            Color(red: 0.85, green: 0.70, blue: 0.40).opacity(0.06),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 60,
                        endRadius: 650
                    )
                }
            } else {
                // 清简现代：极简纯净微光
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
