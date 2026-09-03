import SwiftUI

struct CelestialStarNodeView: View {
    @Environment(\.colorScheme) private var colorScheme

    let node: ConstellationNodeSnapshot
    let isSelected: Bool
    let isHovered: Bool
    let opacity: Double
    let onSelect: () -> Void
    let onOpen: () -> Void

    private var stage: MasteryStage {
        MasteryStage.stage(for: node.score)
    }

    private var isBlocked: Bool {
        if case .blocked = node.topologyStatus { return true }
        return false
    }

    private var isReadyToLearn: Bool {
        if case .readyToLearn = node.topologyStatus { return true }
        return false
    }

    private var masteryColor: Color {
        switch stage {
        case .mastered, .connected: AscendTheme.gold
        case .integrated: AscendTheme.jade
        case .proficient: AscendTheme.cobalt
        case .advancing: AscendTheme.amber
        case .entry: AscendTheme.cinnabar
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 5) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(masteryColor.opacity(colorScheme == .dark ? 0.35 : 0.22))
                            .frame(width: 48, height: 48)
                            .blur(radius: 5)
                    }

                    if isReadyToLearn && !isSelected {
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    gradient: Gradient(colors: [AscendTheme.gold, AscendTheme.jade, AscendTheme.gold]),
                                    center: .center
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: AscendTheme.gold.opacity(0.3), radius: 4)
                    }

                    if isBlocked {
                        Circle()
                            .stroke(AscendTheme.cinnabar.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            .frame(width: 34, height: 34)
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    colorScheme == .dark ? Color.white.opacity(0.85) : masteryColor.opacity(0.2),
                                    masteryColor,
                                    colorScheme == .dark ? masteryColor.opacity(0.7) : masteryColor.opacity(0.9)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 16
                            )
                        )
                        .frame(
                            width: isSelected ? 26 : (isHovered ? 24 : 20),
                            height: isSelected ? 26 : (isHovered ? 24 : 20)
                        )
                        .shadow(
                            color: masteryColor.opacity(isSelected ? 0.85 : (isHovered ? 0.6 : 0.35)),
                            radius: isSelected ? 8 : 4
                        )

                    if isBlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white)
                            .shadow(color: Color.black.opacity(0.6), radius: 2)
                    } else if stage == .mastered || stage == .connected {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 48, height: 48)

                Text(node.name)
                    .font(.system(size: isSelected ? 12 : 11, weight: isSelected ? .bold : .medium, design: .serif))
                    .foregroundStyle(
                        isSelected
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : (colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary.opacity(0.85))
                    )
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                            ? (colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.85))
                            : Color.clear
                    )
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .opacity(opacity)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { onOpen() }
        )
    }
}
