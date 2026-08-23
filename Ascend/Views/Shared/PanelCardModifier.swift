import SwiftUI

struct PanelCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(AscendTheme.surface(for: colorScheme).opacity(colorScheme == .dark ? 0.78 : 0.72))
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AscendTheme.border(for: colorScheme), lineWidth: 1)
            }
    }
}

extension View {
    func panelCard() -> some View {
        modifier(PanelCardModifier())
    }
}
