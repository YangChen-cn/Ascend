import AppKit
import SwiftUI

struct MenuBarDomainRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let domain: DomainProgressSnapshot
    let action: () -> Void

    @State private var isHovered = false

    private var progress: CGFloat {
        max(0, min(1, CGFloat(domain.currentScore / 100)))
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(domain.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MenuBarPalette.ink(colorScheme))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text("\(domain.currentRealm.title) · \(Int(domain.currentScore.rounded()))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MenuBarPalette.gold(colorScheme))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(MenuBarPalette.jade(colorScheme))
                        .opacity(isHovered ? 0.85 : 0.18)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(MenuBarPalette.ink(colorScheme).opacity(0.10))
                            .frame(height: 1.5)

                        Capsule()
                            .fill(MenuBarPalette.jade(colorScheme))
                            .frame(width: proxy.size.width * progress, height: 1.5)

                        Circle()
                            .fill(MenuBarPalette.jade(colorScheme))
                            .frame(width: 4, height: 4)
                            .offset(x: max(0, proxy.size.width * progress - 2))
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(MenuBarPalette.hoverFill(colorScheme).opacity(isHovered ? 1 : 0))
            .clipShape(.rect(cornerRadius: 5))
            .contentShape(.rect)
        }
        .buttonStyle(MenuBarPressButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            (hovering ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
        .help("打开 \(domain.name) 的能力地图")
    }
}
