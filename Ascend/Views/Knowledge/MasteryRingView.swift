import SwiftUI

struct MasteryRingView: View {
    let score: Double
    @Environment(\.colorScheme) private var colorScheme

    private var stage: MasteryStage {
        MasteryStage.stage(for: score)
    }

    var body: some View {
        ZStack {
            // 底层灵气暗环
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.06),
                            Color.primary.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 10
                )

            // 发光渐变进度环
            Circle()
                .trim(from: 0, to: max(0.01, min(1.0, score / 100)))
                .stroke(
                    LinearGradient(
                        colors: [
                            AscendTheme.gold,
                            AscendTheme.jade,
                            AscendTheme.cobalt
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AscendTheme.jade.opacity(0.40), radius: 8)

            // 核心数值与境界
            VStack(spacing: 2) {
                Text(Int(score.rounded()).formatted())
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(AscendTheme.gold)

                Text(stage.rawValue)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(AscendTheme.jade)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AscendTheme.jade.opacity(0.12))
                    .clipShape(.capsule)
            }
        }
        .frame(width: 145, height: 145)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("掌握 \(Int(score.rounded()))，境界 \(stage.rawValue)")
    }
}
