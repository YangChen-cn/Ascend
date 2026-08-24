import SwiftUI

struct PanelCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background {
                if AscendTheme.isXuanqing {
                    RoundedRectangle(cornerRadius: AscendTheme.Radius.surface)
                        .fill(AscendTheme.subtleSurface(for: colorScheme))
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AscendTheme.Radius.surface))
                } else {
                    RoundedRectangle(cornerRadius: AscendTheme.Radius.surface)
                        .fill(AscendTheme.surface(for: colorScheme))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AscendTheme.Radius.surface)
                    .strokeBorder(
                        isHighlighted ? AscendTheme.gold.opacity(0.52) : AscendTheme.separator(for: colorScheme),
                        lineWidth: isHighlighted ? 1.2 : 0.7
                    )
            }
            .shadow(
                color: isHighlighted
                    ? AscendTheme.gold.opacity(0.12)
                    : (colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.025)),
                radius: isHighlighted ? 9 : 4,
                x: 0,
                y: isHighlighted ? 3 : 1
            )
    }
}

extension View {
    func panelCard(highlighted: Bool = false) -> some View {
        modifier(PanelCardModifier(isHighlighted: highlighted))
    }
}
