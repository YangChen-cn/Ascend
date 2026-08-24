import SwiftUI

enum SectionSurfaceStyle: Sendable {
    case plain
    case grouped
    case emphasized
}

private struct SectionSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let style: SectionSurfaceStyle

    func body(content: Content) -> some View {
        switch style {
        case .plain:
            content
        case .grouped:
            content
                .padding(14)
                .background(AscendTheme.subtleSurface(for: colorScheme), in: .rect(cornerRadius: AscendTheme.Radius.surface))
                .overlay {
                    RoundedRectangle(cornerRadius: AscendTheme.Radius.surface)
                        .strokeBorder(AscendTheme.separator(for: colorScheme), lineWidth: 0.7)
                }
        case .emphasized:
            content
                .padding(15)
                .background(AscendTheme.elevatedSurface(for: colorScheme), in: .rect(cornerRadius: AscendTheme.Radius.emphasized))
                .overlay {
                    RoundedRectangle(cornerRadius: AscendTheme.Radius.emphasized)
                        .strokeBorder(AscendTheme.gold.opacity(0.42), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.05), radius: 7, y: 2)
        }
    }
}

extension View {
    func sectionSurface(_ style: SectionSurfaceStyle = .grouped) -> some View {
        modifier(SectionSurfaceModifier(style: style))
    }
}
