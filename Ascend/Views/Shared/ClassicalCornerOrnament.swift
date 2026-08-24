import SwiftUI

/// 中国传统装裱四角云纹/回纹微角饰
/// 纯代码 Path 绘制，为卡片与面板赋予古籍经卷、金石字画的精致装裱感
struct ClassicalCornerOrnament: View {
    var size: CGFloat = 12
    var color: Color = AscendTheme.gold.opacity(0.40)

    var body: some View {
        Canvas { context, canvasSize in
            // 左上角古典回纹
            drawFretCorner(in: context, origin: CGPoint(x: 0, y: 0), size: size, flipX: false, flipY: false)
            // 右上角古典回纹
            drawFretCorner(in: context, origin: CGPoint(x: canvasSize.width, y: 0), size: size, flipX: true, flipY: false)
            // 左下角古典回纹
            drawFretCorner(in: context, origin: CGPoint(x: 0, y: canvasSize.height), size: size, flipX: false, flipY: true)
            // 右下角古典回纹
            drawFretCorner(in: context, origin: CGPoint(x: canvasSize.width, y: canvasSize.height), size: size, flipX: true, flipY: true)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawFretCorner(
        in context: GraphicsContext,
        origin: CGPoint,
        size: CGFloat,
        flipX: Bool,
        flipY: Bool
    ) {
        let sx: CGFloat = flipX ? -1 : 1
        let sy: CGFloat = flipY ? -1 : 1

        var path = Path()
        // 外角折线
        path.move(to: CGPoint(x: origin.x, y: origin.y + size * sy))
        path.addLine(to: CGPoint(x: origin.x, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + size * sx, y: origin.y))

        // 内角回纹微勾
        let inset = size * 0.38
        path.move(to: CGPoint(x: origin.x + inset * sx, y: origin.y + size * 0.75 * sy))
        path.addLine(to: CGPoint(x: origin.x + inset * sx, y: origin.y + inset * sy))
        path.addLine(to: CGPoint(x: origin.x + size * 0.75 * sx, y: origin.y + inset * sy))

        context.stroke(
            path,
            with: .color(color),
            lineWidth: 0.9
        )
    }
}
