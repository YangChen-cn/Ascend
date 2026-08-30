import SwiftUI

/// 焚香计时主视觉：一根横香随进度燃短，香头火星缓闪、青烟上飘。
/// `progress` 0 → 1 表示燃尽比例；`isBurning` 控制火星与青烟的动态。
/// 青烟颜色随明暗模式调校：浅色用墨灰、深色用淡白，避免"白烟画白底"。
struct IncenseBurnView: View {
    let progress: Double
    var isBurning: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? nil : 1.0 / 30.0, paused: !isBurning || reduceMotion)) { timeline in
            Canvas { context, size in
                let t = reduceMotion
                    ? 0.0
                    : timeline.date.timeIntervalSinceReferenceDate
                draw(in: &context, size: size, time: t)
            }
        }
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let burned = Int((progress * 100).rounded())
        return isBurning ? "焚香计时，已燃 \(burned)%" : "焚香静置，已燃 \(burned)%"
    }

    // MARK: 绘制

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let stickStart = CGPoint(x: size.width * 0.18, y: size.height * 0.64)
        let stickEnd = CGPoint(x: size.width * 0.94, y: stickStart.y)
        let length = stickEnd.x - stickStart.x
        let clamp = min(max(progress, 0), 1)
        let ember = CGPoint(x: stickStart.x + length * clamp, y: stickStart.y)

        if isBurning, clamp < 1 {
            drawWarmAmbience(in: &context, at: ember, size: size)
        }

        drawDish(in: &context, at: stickStart)
        drawTicks(in: &context, start: stickStart, length: length)

        if clamp > 0 {
            drawAsh(in: &context, from: stickStart.x, to: ember.x, y: stickStart.y, time: time)
        }
        drawRemainingStick(in: &context, from: ember.x, to: stickEnd.x, y: stickStart.y)

        if isBurning, clamp < 1 {
            drawEmber(in: &context, at: ember, time: time)
            drawSmoke(in: &context, from: CGPoint(x: ember.x, y: stickStart.y - 3), size: size, time: time)
        }
    }

    private var smokeColor: Color {
        colorScheme == .dark ? Color(white: 0.88) : Color(red: 0.32, green: 0.34, blue: 0.34)
    }

    /// 火星背后的暖色氛围：把整段视觉从"一条线"变回"一炉香"。
    private func drawWarmAmbience(in context: inout GraphicsContext, at ember: CGPoint, size: CGSize) {
        let radius = size.height * 0.62
        let rect = CGRect(
            x: ember.x - radius,
            y: ember.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    AscendTheme.gold.opacity(colorScheme == .dark ? 0.16 : 0.13),
                    AscendTheme.gold.opacity(0.05),
                    .clear
                ]),
                center: ember,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    /// 香插小碟：实心浅碟托住香脚，暖金描边。
    private func drawDish(in context: inout GraphicsContext, at anchor: CGPoint) {
        let dishWidth: CGFloat = 40
        let dishHeight: CGFloat = 13
        let dishRect = CGRect(
            x: anchor.x - dishWidth * 0.62,
            y: anchor.y + 4,
            width: dishWidth,
            height: dishHeight
        )
        // 实心碟身：上半圆填底
        let dish = Path { path in
            path.addArc(
                center: CGPoint(x: dishRect.midX, y: dishRect.minY),
                radius: dishWidth / 2,
                startAngle: .degrees(6),
                endAngle: .degrees(174),
                clockwise: true
            )
            path.closeSubpath()
        }
        context.fill(dish, with: .color(AscendTheme.gold.opacity(colorScheme == .dark ? 0.22 : 0.16)))
        context.stroke(
            dish,
            with: .color(AscendTheme.gold.opacity(colorScheme == .dark ? 0.62 : 0.5)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
        )
    }

    /// 香刻度：四分位极细标记，暗合古时香篆计时。
    private func drawTicks(in context: inout GraphicsContext, start: CGPoint, length: CGFloat) {
        for fraction in [0.25, 0.5, 0.75] {
            let x = start.x + length * fraction
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: start.y + 8))
            tick.addLine(to: CGPoint(x: x, y: start.y + 11))
            context.stroke(
                tick,
                with: .color(Color.primary.opacity(0.2)),
                lineWidth: 1
            )
        }
    }

    /// 燃尽的灰：低透明度断续残迹，随时间极轻微抖落。
    private func drawAsh(in context: inout GraphicsContext, from startX: CGFloat, to endX: CGFloat, y: CGFloat, time: TimeInterval) {
        var ash = Path()
        let jitter = reduceMotion ? 0 : CGFloat(sin(time * 0.7) * 0.4)
        ash.move(to: CGPoint(x: startX + 5, y: y + 1 + jitter))
        ash.addLine(to: CGPoint(x: endX, y: y + 1))
        context.stroke(
            ash,
            with: .color(Color.primary.opacity(0.22)),
            style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [2.5, 3.5])
        )
    }

    /// 未燃的香身：墨玉沉香色，微高光。
    private func drawRemainingStick(in context: inout GraphicsContext, from startX: CGFloat, to endX: CGFloat, y: CGFloat) {
        guard endX > startX else { return }
        let stick = Path { path in
            path.move(to: CGPoint(x: startX, y: y))
            path.addLine(to: CGPoint(x: endX, y: y))
        }
        let gradient = Gradient(colors: [
            AscendTheme.inkJade.opacity(0.95),
            AscendTheme.deepJade.opacity(0.8)
        ])
        context.stroke(
            stick,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: startX, y: y - 2),
                endPoint: CGPoint(x: endX, y: y + 2)
            ),
            style: StrokeStyle(lineWidth: 4.2, lineCap: .round)
        )
        var highlight = Path()
        highlight.move(to: CGPoint(x: startX, y: y - 1.1))
        highlight.addLine(to: CGPoint(x: endX, y: y - 1.1))
        context.stroke(
            highlight,
            with: .color(Color.white.opacity(colorScheme == .dark ? 0.3 : 0.4)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round)
        )
    }

    /// 香头火星：呼吸式脉动的暖金光点 + 核心亮点。
    private func drawEmber(in context: inout GraphicsContext, at point: CGPoint, time: TimeInterval) {
        let pulse = reduceMotion
            ? 0.85
            : 0.78 + 0.22 * sin(time * 2 * .pi / 1.6)
        let radius: CGFloat = 11 * pulse

        context.fill(
            Path(ellipseIn: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    AscendTheme.gold.opacity(0.9),
                    AscendTheme.amber.opacity(0.42),
                    .clear
                ]),
                center: point,
                startRadius: 0,
                endRadius: radius
            )
        )
        let coreRadius: CGFloat = 2.4
        context.fill(
            Path(ellipseIn: CGRect(
                x: point.x - coreRadius,
                y: point.y - coreRadius,
                width: coreRadius * 2,
                height: coreRadius * 2
            )),
            with: .color(Color(red: 1.0, green: 0.85, blue: 0.52))
        )
    }

    /// 青烟：两缕贝塞尔细线自香头盘旋上飘，渐次消散。
    private func drawSmoke(in context: inout GraphicsContext, from origin: CGPoint, size: CGSize, time: TimeInterval) {
        guard !reduceMotion else { return }
        let smokeHeight = min(size.height * 0.56, 86)
        for wisp in 0..<2 {
            let phase = Double(wisp) * 2.1
            let drift = wisp == 0 ? 1.0 : -0.7
            var path = Path()
            path.move(to: origin)
            let segments = 14
            var previousPoint = origin
            for step in 1...segments {
                let fraction = Double(step) / Double(segments)
                let y = origin.y - smokeHeight * fraction
                let sway = sin(time * (0.9 + Double(wisp) * 0.15) + fraction * 4.6 + phase)
                let x = origin.x + CGFloat(sway) * (5 + 10 * fraction) * drift + CGFloat(fraction) * 5
                let point = CGPoint(x: x, y: y)
                let midY = (previousPoint.y + y) / 2
                let midX = (previousPoint.x + x) / 2 + CGFloat(sin(time + fraction * 3)) * 1.5
                path.addQuadCurve(
                    to: point,
                    control: CGPoint(x: midX, y: midY)
                )
                previousPoint = point
            }
            let alpha = wisp == 0 ? 0.5 : 0.3
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        smokeColor.opacity(alpha),
                        smokeColor.opacity(alpha * 0.45),
                        .clear
                    ]),
                    startPoint: origin,
                    endPoint: CGPoint(x: origin.x, y: origin.y - smokeHeight)
                ),
                style: StrokeStyle(lineWidth: wisp == 0 ? 1.5 : 1.1, lineCap: .round)
            )
        }
    }
}
