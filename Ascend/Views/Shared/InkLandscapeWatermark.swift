import SwiftUI

/// 中国传统水墨山水与祥云写意意象组件
/// 纯代码绘制，支持高分辨率自适应、明暗模式无缝切换与水墨氤氲感
struct InkLandscapeWatermark: View {
    @Environment(\.colorScheme) private var colorScheme
    var height: CGFloat = 140
    var opacity: Double = 0.85

    var body: some View {
        if AscendTheme.isXuanqing {
            GeometryReader { proxy in
                Canvas { context, size in
                    // 远山第一重（远景淡墨青岚）
                    var farMountain = Path()
                    farMountain.move(to: CGPoint(x: 0, y: size.height))
                    farMountain.addLine(to: CGPoint(x: 0, y: size.height * 0.45))
                    farMountain.addCurve(
                        to: CGPoint(x: size.width * 0.35, y: size.height * 0.22),
                        control1: CGPoint(x: size.width * 0.12, y: size.height * 0.42),
                        control2: CGPoint(x: size.width * 0.22, y: size.height * 0.18)
                    )
                    farMountain.addCurve(
                        to: CGPoint(x: size.width * 0.65, y: size.height * 0.38),
                        control1: CGPoint(x: size.width * 0.45, y: size.height * 0.26),
                        control2: CGPoint(x: size.width * 0.55, y: size.height * 0.45)
                    )
                    farMountain.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.15),
                        control1: CGPoint(x: size.width * 0.78, y: size.height * 0.30),
                        control2: CGPoint(x: size.width * 0.90, y: size.height * 0.12)
                    )
                    farMountain.addLine(to: CGPoint(x: size.width, y: size.height))
                    farMountain.closeSubpath()

                    let farGradient = Gradient(colors: [
                        inkFarColor.opacity(0.14 * opacity),
                        inkFarColor.opacity(0.02 * opacity),
                        .clear
                    ])
                    context.fill(farMountain, with: .linearGradient(farGradient, startPoint: CGPoint(x: 0, y: size.height * 0.15), endPoint: CGPoint(x: 0, y: size.height)))

                    // 远山第二重（中景水墨层峦）
                    var midMountain = Path()
                    midMountain.move(to: CGPoint(x: 0, y: size.height))
                    midMountain.addLine(to: CGPoint(x: 0, y: size.height * 0.62))
                    midMountain.addCurve(
                        to: CGPoint(x: size.width * 0.28, y: size.height * 0.40),
                        control1: CGPoint(x: size.width * 0.08, y: size.height * 0.58),
                        control2: CGPoint(x: size.width * 0.18, y: size.height * 0.36)
                    )
                    midMountain.addCurve(
                        to: CGPoint(x: size.width * 0.58, y: size.height * 0.55),
                        control1: CGPoint(x: size.width * 0.38, y: size.height * 0.44),
                        control2: CGPoint(x: size.width * 0.48, y: size.height * 0.60)
                    )
                    midMountain.addCurve(
                        to: CGPoint(x: size.width * 0.85, y: size.height * 0.32),
                        control1: CGPoint(x: size.width * 0.68, y: size.height * 0.50),
                        control2: CGPoint(x: size.width * 0.76, y: size.height * 0.28)
                    )
                    midMountain.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.48),
                        control1: CGPoint(x: size.width * 0.92, y: size.height * 0.36),
                        control2: CGPoint(x: size.width * 0.96, y: size.height * 0.52)
                    )
                    midMountain.addLine(to: CGPoint(x: size.width, y: size.height))
                    midMountain.closeSubpath()

                    let midGradient = Gradient(colors: [
                        inkMidColor.opacity(0.20 * opacity),
                        inkMidColor.opacity(0.04 * opacity),
                        .clear
                    ])
                    context.fill(midMountain, with: .linearGradient(midGradient, startPoint: CGPoint(x: 0, y: size.height * 0.30), endPoint: CGPoint(x: 0, y: size.height)))

                    // 近景水墨峦影（带墨晕微峰）
                    var nearMountain = Path()
                    nearMountain.move(to: CGPoint(x: 0, y: size.height))
                    nearMountain.addLine(to: CGPoint(x: 0, y: size.height * 0.80))
                    nearMountain.addCurve(
                        to: CGPoint(x: size.width * 0.22, y: size.height * 0.65),
                        control1: CGPoint(x: size.width * 0.06, y: size.height * 0.75),
                        control2: CGPoint(x: size.width * 0.14, y: size.height * 0.62)
                    )
                    nearMountain.addCurve(
                        to: CGPoint(x: size.width * 0.48, y: size.height * 0.72),
                        control1: CGPoint(x: size.width * 0.30, y: size.height * 0.68),
                        control2: CGPoint(x: size.width * 0.40, y: size.height * 0.78)
                    )
                    nearMountain.addCurve(
                        to: CGPoint(x: size.width * 0.75, y: size.height * 0.56),
                        control1: CGPoint(x: size.width * 0.58, y: size.height * 0.66),
                        control2: CGPoint(x: size.width * 0.66, y: size.height * 0.52)
                    )
                    nearMountain.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.70),
                        control1: CGPoint(x: size.width * 0.85, y: size.height * 0.60),
                        control2: CGPoint(x: size.width * 0.94, y: size.height * 0.72)
                    )
                    nearMountain.addLine(to: CGPoint(x: size.width, y: size.height))
                    nearMountain.closeSubpath()

                    let nearGradient = Gradient(colors: [
                        inkNearColor.opacity(0.26 * opacity),
                        inkNearColor.opacity(0.06 * opacity),
                        .clear
                    ])
                    context.fill(nearMountain, with: .linearGradient(nearGradient, startPoint: CGPoint(x: 0, y: size.height * 0.50), endPoint: CGPoint(x: 0, y: size.height)))

                    // 水墨祥云与行雁
                    drawInkBirds(context: context, size: size)
                }
            }
            .frame(height: height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var inkFarColor: Color {
        colorScheme == .dark
            ? Color(red: 0.18, green: 0.42, blue: 0.40)
            : Color(red: 0.40, green: 0.48, blue: 0.46)
    }

    private var inkMidColor: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.32, blue: 0.30)
            : Color(red: 0.28, green: 0.38, blue: 0.36)
    }

    private var inkNearColor: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.25, blue: 0.24)
            : Color(red: 0.20, green: 0.28, blue: 0.26)
    }

    private func drawInkBirds(context: GraphicsContext, size: CGSize) {
        let birds = [
            CGPoint(x: size.width * 0.72, y: size.height * 0.22),
            CGPoint(x: size.width * 0.76, y: size.height * 0.18),
            CGPoint(x: size.width * 0.81, y: size.height * 0.24)
        ]

        for (index, bird) in birds.enumerated() {
            let scale: CGFloat = index == 1 ? 1.2 : 0.85
            var wing = Path()
            wing.move(to: CGPoint(x: bird.x - 6 * scale, y: bird.y + 2 * scale))
            wing.addQuadCurve(to: bird, control: CGPoint(x: bird.x - 3 * scale, y: bird.y - 4 * scale))
            wing.addQuadCurve(to: CGPoint(x: bird.x + 6 * scale, y: bird.y + 2 * scale), control: CGPoint(x: bird.x + 3 * scale, y: bird.y - 4 * scale))

            context.stroke(
                wing,
                with: .color((colorScheme == .dark ? AscendTheme.gold : inkNearColor).opacity(0.40 * opacity)),
                lineWidth: 1.0 * scale
            )
        }
    }
}
