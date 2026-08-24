import SwiftUI

struct GraphNodeButton: View {
    let node: KnowledgeNode
    let mastery: Double
    let isCenter: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var stage: MasteryStage {
        MasteryStage.stage(for: mastery)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // 外层灵气光晕
                Circle()
                    .fill(auraColor.opacity(isHovered ? 0.35 : (isCenter ? 0.22 : 0.14)))
                    .frame(width: nodeSize + 24, height: nodeSize + 24)
                    .blur(radius: isHovered ? 12 : 8)

                // 核心星宿球体
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AscendTheme.surface(for: colorScheme),
                                colorScheme == .dark ? Color(red: 0.05, green: 0.09, blue: 0.12) : Color(red: 0.94, green: 0.96, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: nodeSize, height: nodeSize)

                // 灵纹勾边
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: strokeColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 2.5 : (isCenter ? 2.0 : 1.2)
                    )
                    .frame(width: nodeSize, height: nodeSize)

                // 内容
                VStack(spacing: 3) {
                    Text(node.name)
                        .font(.system(isCenter ? .headline : .callout, design: .serif))
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .frame(height: isCenter ? 58 : 50)
                        .padding(.horizontal, 10)

                    Text(Int(mastery.rounded()).formatted())
                        .font(.system(isCenter ? .title2 : .body, design: .rounded))
                        .bold()
                        .foregroundStyle(scoreColor)

                    Text(stage.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: nodeSize - 8)
            }
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(node.name)
        .accessibilityLabel("\(node.name)，掌握度 \(Int(mastery.rounded()))，境界 \(stage.rawValue)")
    }

    private var nodeSize: CGFloat {
        isCenter ? 152 : 122
    }

    private var auraColor: Color {
        switch stage {
        case .mastered, .connected: AscendTheme.gold
        case .integrated: AscendTheme.jade
        case .proficient: AscendTheme.cobalt
        case .advancing, .entry: AscendTheme.slate
        }
    }

    private var scoreColor: Color {
        switch stage {
        case .mastered, .connected: AscendTheme.gold
        case .integrated: AscendTheme.jade
        case .proficient: AscendTheme.cobalt
        case .advancing, .entry: .primary
        }
    }

    private var strokeColors: [Color] {
        switch stage {
        case .mastered, .connected:
            [AscendTheme.gold, AscendTheme.jade.opacity(0.6), AscendTheme.gold.opacity(0.3)]
        case .integrated:
            [AscendTheme.jade, AscendTheme.cobalt.opacity(0.6), AscendTheme.jade.opacity(0.3)]
        case .proficient:
            [AscendTheme.cobalt, Color.cyan.opacity(0.5), AscendTheme.cobalt.opacity(0.3)]
        case .advancing, .entry:
            [AscendTheme.border(for: colorScheme), Color.secondary.opacity(0.2)]
        }
    }
}
