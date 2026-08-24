import AppKit
import SwiftUI

struct MenuBarStatsCell: View {
    @Environment(\.colorScheme) private var colorScheme

    let number: String
    let title: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    private var talismanAccentColor: Color {
        switch title {
        case "知识", "资料流", "资料":
            return MenuBarPalette.jade(colorScheme)
        case "能力", "挑战":
            return MenuBarPalette.gold(colorScheme)
        case "复习", "待确认":
            return MenuBarPalette.cinnabar(colorScheme)
        default:
            return MenuBarPalette.jade(colorScheme)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // 道签左缘色彩标识
                Capsule()
                    .fill(talismanAccentColor.opacity(isHovered ? 0.95 : 0.65))
                    .frame(width: 2.5, height: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 2) {
                        Text(title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))

                        Spacer(minLength: 2)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 7.5, weight: .semibold))
                            .foregroundStyle(talismanAccentColor)
                            .opacity(isHovered ? 0.9 : 0.3)
                            .offset(x: isHovered ? 1 : 0)
                    }

                    Text(number)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MenuBarPalette.ink(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isHovered
                            ? talismanAccentColor.opacity(colorScheme == .dark ? 0.12 : 0.08)
                            : Color.primary.opacity(0.035)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isHovered
                            ? talismanAccentColor.opacity(0.45)
                            : Color.primary.opacity(0.08),
                        lineWidth: 0.8
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
