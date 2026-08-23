import AppKit
import SwiftUI

struct MenuBarStatsCell: View {
    @Environment(\.colorScheme) private var colorScheme

    let number: String
    let title: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))

                    Spacer(minLength: 2)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(MenuBarPalette.jade(colorScheme))
                        .opacity(isHovered ? 0.9 : 0.22)
                        .offset(x: isHovered ? 1 : 0)
                }

                Text(number)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MenuBarPalette.ink(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(MenuBarPalette.hoverFill(colorScheme).opacity(isHovered ? 1 : 0))
            .clipShape(.rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        MenuBarPalette.hoverStroke(colorScheme).opacity(isHovered ? 1 : 0),
                        lineWidth: 0.6
                    )
            }
            .contentShape(.rect)
        }
        .buttonStyle(MenuBarPressButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            (hovering ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
        .help(help)
    }
}
