import SwiftUI

/// 休息阶段呼吸引导：青玉雾环以 6 秒周期缓缓开合。
struct RestBreathView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? nil : 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = reduceMotion
                    ? 0.0
                    : timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let base = min(size.width, size.height) * 0.3
                let scale = 1 + 0.14 * sin(t * 2 * .pi / 6)
                let radius = base * scale

                for (offset, opacity) in [(0.0, 0.36), (0.5, 0.2), (1.0, 0.09)] {
                    let ringRadius = radius * (1 - offset * 0.35)
                    let rect = CGRect(
                        x: center.x - ringRadius,
                        y: center.y - ringRadius,
                        width: ringRadius * 2,
                        height: ringRadius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [AscendTheme.jade.opacity(opacity), .clear]),
                            center: center,
                            startRadius: ringRadius * 0.4,
                            endRadius: ringRadius
                        )
                    )
                }
                let coreRadius = radius * 0.34
                context.stroke(
                    Path(ellipseIn: CGRect(
                        x: center.x - coreRadius,
                        y: center.y - coreRadius,
                        width: coreRadius * 2,
                        height: coreRadius * 2
                    )),
                    with: .color(AscendTheme.jade.opacity(0.55)),
                    lineWidth: 1.4
                )
            }
        }
        .accessibilityLabel("休息中，跟随呼吸放松")
    }
}
