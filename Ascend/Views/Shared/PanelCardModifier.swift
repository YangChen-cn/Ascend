import SwiftUI

struct PanelCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                if AscendTheme.isXuanqing {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AscendTheme.surface(for: colorScheme))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: AscendTheme.Radius.surface)
                        .fill(AscendTheme.surface(for: colorScheme))
                }
            }
            .overlay {
                if AscendTheme.isXuanqing {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isHighlighted
                                ? LinearGradient(
                                    colors: [AscendTheme.gold, AscendTheme.jade.opacity(0.7), AscendTheme.gold.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        AscendTheme.gold.opacity(colorScheme == .dark ? 0.38 : 0.30),
                                        AscendTheme.border(for: colorScheme),
                                        AscendTheme.border(for: colorScheme).opacity(0.40)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: isHighlighted ? 1.2 : 0.85
                        )
                } else {
                    RoundedRectangle(cornerRadius: AscendTheme.Radius.surface)
                        .strokeBorder(
                            isHighlighted ? AscendTheme.cobalt.opacity(0.5) : AscendTheme.border(for: colorScheme),
                            lineWidth: 1
                        )
                }
            }
            .shadow(
                color: isHighlighted
                    ? AscendTheme.gold.opacity(0.18)
                    : (colorScheme == .dark ? Color.black.opacity(0.28) : Color.black.opacity(0.03)),
                radius: isHighlighted ? 10 : 5,
                x: 0,
                y: isHighlighted ? 3 : 1.5
            )
    }
}

extension View {
    func panelCard(highlighted: Bool = false) -> some View {
        modifier(PanelCardModifier(isHighlighted: highlighted))
    }
}
