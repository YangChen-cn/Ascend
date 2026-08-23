import SwiftUI

struct PanelCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(22)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AscendTheme.surface(for: colorScheme).opacity(colorScheme == .dark ? 0.85 : 0.82))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isHighlighted
                                ? [AscendTheme.gold.opacity(0.8), AscendTheme.jade.opacity(0.4), AscendTheme.gold.opacity(0.2)]
                                : [
                                    colorScheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.8),
                                    AscendTheme.border(for: colorScheme),
                                    AscendTheme.border(for: colorScheme).opacity(0.4)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: isHighlighted
                    ? AscendTheme.gold.opacity(colorScheme == .dark ? 0.20 : 0.12)
                    : Color.black.opacity(colorScheme == .dark ? 0.35 : 0.05),
                radius: isHighlighted ? 16 : 10,
                x: 0,
                y: isHighlighted ? 6 : 3
            )
    }
}

extension View {
    func panelCard(highlighted: Bool = false) -> some View {
        modifier(PanelCardModifier(isHighlighted: highlighted))
    }
}
