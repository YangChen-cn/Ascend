import SwiftUI

struct FeaturePageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AscendTheme.background(for: colorScheme)

            if colorScheme == .dark {
                // 太虚玄渊流转的灵气烟岚
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
                // 素绢云宣上的淡墨青岚
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
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
