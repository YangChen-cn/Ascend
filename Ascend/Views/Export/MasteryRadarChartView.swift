import SwiftUI

struct MasteryRadarChartView: View {
    let vector: MasteryVector
    var isDark: Bool = true
    var size: CGFloat = 200

    private let dimensions: [(name: String, weight: String, keyPath: KeyPath<MasteryVector, Double>)] = [
        ("接触", "10%", \.exposure),
        ("理解", "25%", \.understanding),
        ("实践", "25%", \.practice),
        ("记忆", "20%", \.retention),
        ("自主", "20%", \.autonomy)
    ]

    var body: some View {
        ZStack {
            // 背景五边形网格
            ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { level in
                polygonPath(radius: (size / 2 - 28) * level)
                    .stroke(
                        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08),
                        style: StrokeStyle(lineWidth: level == 1.0 ? 1.2 : 0.8, dash: level == 1.0 ? [] : [3, 4])
                    )
            }

            // 径向轴线
            ForEach(0..<5, id: \.self) { index in
                axisLine(index: index, radius: size / 2 - 28)
                    .stroke(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.10), lineWidth: 0.8)
            }

            // 掌握度五边形填充与发光
            dataPolygonPath(radius: size / 2 - 28)
                .fill(
                    LinearGradient(
                        colors: [
                            AscendTheme.gold.opacity(isDark ? 0.35 : 0.40),
                            AscendTheme.jade.opacity(isDark ? 0.25 : 0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            dataPolygonPath(radius: size / 2 - 28)
                .stroke(
                    LinearGradient(
                        colors: [AscendTheme.gold, AscendTheme.jade],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )

            // 五维顶点数字与指示点
            ForEach(0..<5, id: \.self) { index in
                let val = vector[keyPath: dimensions[index].keyPath]
                let point = pointOnAxis(index: index, radius: (size / 2 - 28) * CGFloat(min(1.0, max(0.05, val / 100.0))))
                Circle()
                    .fill(AscendTheme.gold)
                    .frame(width: 5, height: 5)
                    .position(point)
            }

            // 维度标签
            ForEach(0..<5, id: \.self) { index in
                let dim = dimensions[index]
                let val = Int(vector[keyPath: dim.keyPath].rounded())
                let labelPos = labelPosition(index: index, radius: size / 2 - 10)

                VStack(spacing: 1) {
                    Text(dim.name)
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .foregroundStyle(isDark ? Color.white : Color.primary)
                    Text("\(val)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(AscendTheme.gold)
                }
                .position(labelPos)
            }
        }
        .frame(width: size, height: size)
    }

    private func polygonPath(radius: CGFloat) -> Path {
        var path = Path()
        let center = CGPoint(x: size / 2, y: size / 2)
        for i in 0..<5 {
            let angle = (Double(i) * 2 * .pi / 5.0) - (.pi / 2)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func axisLine(index: Int, radius: CGFloat) -> Path {
        var path = Path()
        let center = CGPoint(x: size / 2, y: size / 2)
        let angle = (Double(index) * 2 * .pi / 5.0) - (.pi / 2)
        let end = CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
        path.move(to: center)
        path.addLine(to: end)
        return path
    }

    private func dataPolygonPath(radius: CGFloat) -> Path {
        var path = Path()
        let center = CGPoint(x: size / 2, y: size / 2)
        for i in 0..<5 {
            let val = vector[keyPath: dimensions[i].keyPath]
            let normalized = CGFloat(min(1.0, max(0.05, val / 100.0)))
            let angle = (Double(i) * 2 * .pi / 5.0) - (.pi / 2)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius * normalized,
                y: center.y + CGFloat(sin(angle)) * radius * normalized
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func pointOnAxis(index: Int, radius: CGFloat) -> CGPoint {
        let center = CGPoint(x: size / 2, y: size / 2)
        let angle = (Double(index) * 2 * .pi / 5.0) - (.pi / 2)
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }

    private func labelPosition(index: Int, radius: CGFloat) -> CGPoint {
        let center = CGPoint(x: size / 2, y: size / 2)
        let angle = (Double(index) * 2 * .pi / 5.0) - (.pi / 2)
        let offsetRadius = radius + 10
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * offsetRadius,
            y: center.y + CGFloat(sin(angle)) * offsetRadius
        )
    }
}
