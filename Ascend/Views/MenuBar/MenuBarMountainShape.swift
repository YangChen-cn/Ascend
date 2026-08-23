import SwiftUI

struct MenuBarMountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.82))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.34, y: rect.height * 0.38),
            control1: CGPoint(x: rect.width * 0.10, y: rect.height * 0.78),
            control2: CGPoint(x: rect.width * 0.23, y: rect.height * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.70),
            control1: CGPoint(x: rect.width * 0.43, y: rect.height * 0.46),
            control2: CGPoint(x: rect.width * 0.49, y: rect.height * 0.66)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.34),
            control1: CGPoint(x: rect.width * 0.73, y: rect.height * 0.60),
            control2: CGPoint(x: rect.width * 0.86, y: rect.height * 0.30)
        )
        return path
    }
}
