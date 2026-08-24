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
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: AscendTheme.Radius.surface)
                        .fill(AscendTheme.surface(for: colorScheme))
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AscendTheme.Radius.surface))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AscendTheme.Radius.surface)
                        .strokeBorder(
                            AscendTheme.isXuanqing
                                ? AscendTheme.border(for: colorScheme)
                                : AscendTheme.separator(for: colorScheme),
                            lineWidth: 0.8
                        )
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.025),
                    radius: 4,
                    y: 1.5
                )
        case .emphasized:
            content
                .padding(15)
                .background(AscendTheme.elevatedSurface(for: colorScheme), in: .rect(cornerRadius: AscendTheme.Radius.emphasized))
                .overlay {
                    RoundedRectangle(cornerRadius: AscendTheme.Radius.emphasized)
                        .strokeBorder(
                            AscendTheme.isXuanqing
                                ? LinearGradient(
                                    colors: [AscendTheme.gold.opacity(0.55), AscendTheme.border(for: colorScheme)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(colors: [AscendTheme.gold.opacity(0.42), AscendTheme.gold.opacity(0.20)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04), radius: 6, y: 2)
        }
    }
}

extension View {
    func sectionSurface(_ style: SectionSurfaceStyle = .grouped) -> some View {
        modifier(SectionSurfaceModifier(style: style))
    }
}
