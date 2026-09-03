import SwiftUI

struct ConstellationBaseLeyLinesLayer: View, Equatable {
    let edges: [ConstellationEdgeSnapshot]
    let baseGeometryByID: [UUID: ConstellationEdgeGeometry]
    let geometryOverrides: [UUID: ConstellationEdgeGeometry]
    let drawsPrerequisites: Bool
    let isDark: Bool

    var body: some View {
        Canvas { context, _ in
            for edge in edges where (edge.relation == .prerequisite) == drawsPrerequisites {
                guard let geometry = geometryOverrides[edge.id] ?? baseGeometryByID[edge.id] else { continue }
                drawBaseEdge(geometry, context: &context)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawBaseEdge(_ geometry: ConstellationEdgeGeometry, context: inout GraphicsContext) {
        let isPrerequisite = geometry.relation == .prerequisite
        let alpha = isPrerequisite ? 0.40 : 0.25
        let firstColor = isPrerequisite
            ? AscendTheme.jade.opacity(alpha)
            : (isDark ? AscendTheme.cobalt.opacity(alpha) : AscendTheme.deepJade.opacity(alpha))
        let secondColor = AscendTheme.gold.opacity(alpha)
        let path = curvePath(for: geometry)
        if isPrerequisite {
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [firstColor, secondColor]),
                    startPoint: geometry.source,
                    endPoint: geometry.target
                ),
                lineWidth: 1.6
            )
            context.fill(arrowPath(for: geometry, size: 5.5), with: .color(secondColor))
        } else {
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [firstColor, secondColor]),
                    startPoint: geometry.source,
                    endPoint: geometry.target
                ),
                style: StrokeStyle(lineWidth: 1.1, dash: [4, 4])
            )
        }
    }
}

struct ConstellationHighlightLeyLinesLayer: View, Equatable {
    let highlightedEdgeIDs: Set<UUID>
    let edges: [ConstellationEdgeSnapshot]
    let baseGeometryByID: [UUID: ConstellationEdgeGeometry]
    let geometryOverrides: [UUID: ConstellationEdgeGeometry]

    var body: some View {
        Canvas { context, _ in
            for edge in edges where highlightedEdgeIDs.contains(edge.id) {
                guard let geometry = geometryOverrides[edge.id] ?? baseGeometryByID[edge.id] else { continue }
                let isPrerequisite = geometry.relation == .prerequisite
                let path = curvePath(for: geometry)
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [AscendTheme.gold, AscendTheme.jade]),
                        startPoint: geometry.source,
                        endPoint: geometry.target
                    ),
                    style: isPrerequisite
                        ? StrokeStyle(lineWidth: 2.8)
                        : StrokeStyle(lineWidth: 2.2, dash: [4, 4])
                )
                if isPrerequisite {
                    context.fill(arrowPath(for: geometry, size: 8), with: .color(AscendTheme.jade))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private func curvePath(for geometry: ConstellationEdgeGeometry) -> Path {
    var path = Path()
    path.move(to: geometry.source)
    path.addQuadCurve(to: geometry.target, control: geometry.control)
    return path
}

private func arrowPath(for geometry: ConstellationEdgeGeometry, size: CGFloat) -> Path {
    let t: CGFloat = 0.70
    let inverse = 1 - t
    let x = inverse * inverse * geometry.source.x
        + 2 * inverse * t * geometry.control.x
        + t * t * geometry.target.x
    let y = inverse * inverse * geometry.source.y
        + 2 * inverse * t * geometry.control.y
        + t * t * geometry.target.y
    let tangentX = 2 * inverse * (geometry.control.x - geometry.source.x)
        + 2 * t * (geometry.target.x - geometry.control.x)
    let tangentY = 2 * inverse * (geometry.control.y - geometry.source.y)
        + 2 * t * (geometry.target.y - geometry.control.y)
    let angle = atan2(tangentY, tangentX)
    var path = Path()
    path.move(to: CGPoint(x: x + cos(angle) * size, y: y + sin(angle) * size))
    path.addLine(to: CGPoint(x: x + cos(angle + 2.5) * size, y: y + sin(angle + 2.5) * size))
    path.addLine(to: CGPoint(x: x + cos(angle - 2.5) * size, y: y + sin(angle - 2.5) * size))
    path.closeSubpath()
    return path
}
