import SwiftUI

struct PanelCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background {
                if AscendTheme.isXuanqing {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AscendTheme.surface(for: colorScheme).opacity(colorScheme == .dark ? 0.85 : 0.82))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AscendTheme.surface(for: colorScheme))
                }
            }
            .overlay {
                if AscendTheme.isXuanqing {
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
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isHighlighted ? AscendTheme.cobalt.opacity(0.5) : AscendTheme.border(for: colorScheme),
                            lineWidth: 1
                        )
                }
            }
            .shadow(
                color: isHighlighted
                    ? (AscendTheme.isXuanqing ? AscendTheme.gold.opacity(0.18) : AscendTheme.cobalt.opacity(0.15))
                    : (colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.04)),
                radius: isHighlighted ? 14 : 8,
                x: 0,
                y: isHighlighted ? 5 : 2
            )
    }
}

extension View {
    func panelCard(highlighted: Bool = false) -> some View {
        modifier(PanelCardModifier(isHighlighted: highlighted))
    }
}
