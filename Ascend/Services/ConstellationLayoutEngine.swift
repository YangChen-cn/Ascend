import Foundation

struct ConstellationLayoutEngine: Sendable {
    static let nodeSpacing: CGFloat = 135
    static let minimumCanvasSize = CGSize(width: 960, height: 540)

    func layoutIdentity(
        domainName: String,
        nodes: [(id: UUID, name: String, degree: Int)],
        edges: [ConstellationEdgeSnapshot]
    ) -> String {
        let nodeKey = nodes
            .map { "\($0.id.uuidString):\($0.name)" }
            .sorted()
            .joined(separator: ",")
        let edgeKey = edges
            .map { "\($0.sourceNodeID.uuidString)->\($0.targetNodeID.uuidString):\($0.relation.rawValue)" }
            .sorted()
            .joined(separator: ";")
        return "v2|\(domainName)|\(nodeKey)|\(edgeKey)"
    }

    func canonicalLayout(
        identity: String,
        nodes: [(id: UUID, name: String, degree: Int)]
    ) -> ConstellationGraphLayout {
        guard !nodes.isEmpty else {
            return ConstellationGraphLayout(
                identity: identity,
                canvasSize: Self.minimumCanvasSize,
                canonicalPositions: [:],
                positions: [:],
                canonicalContentBounds: .zero,
                contentBounds: .zero
            )
        }

        let canvasSize = logicalCanvasSize(nodeCount: nodes.count)
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        guard nodes.count > 1 else {
            let positions = [nodes[0].id: center]
            let bounds = ConstellationViewportMath.renderContentBounds(positions: Array(positions.values))
            return ConstellationGraphLayout(
                identity: identity,
                canvasSize: canvasSize,
                canonicalPositions: positions,
                positions: positions,
                canonicalContentBounds: bounds,
                contentBounds: bounds
            )
        }

        let sorted = nodes.sorted { lhs, rhs in
            if lhs.degree != rhs.degree { return lhs.degree > rhs.degree }
            if lhs.name != rhs.name {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        var positions: [UUID: CGPoint] = [sorted[0].id: center]
        let remaining = Array(sorted.dropFirst())
        let ringCapacity = max(6, Int((2 * .pi * min(canvasSize.width, canvasSize.height) * 0.24 / Self.nodeSpacing).rounded(.down)))
        let ringCount = max(1, Int(ceil(Double(remaining.count) / Double(ringCapacity))))
        // 在稳定逻辑画布内预留标题空间，避免 viewport 为标题增加大块虚拟边界后过度缩小。
        let maximumRadiusX = max(160, (canvasSize.width - 300) / 2)
        let maximumRadiusY = max(110, (canvasSize.height - 160) / 2)

        for (index, node) in remaining.enumerated() {
            let ring = min(ringCount - 1, index / ringCapacity)
            let indexInRing = index % ringCapacity
            let nodesInRing = min(ringCapacity, remaining.count - ring * ringCapacity)
            let radiusRatio = CGFloat(ring + 1) / CGFloat(ringCount)
            let angle = (Double(indexInRing) / Double(max(1, nodesInRing))) * 2 * .pi
                - .pi / 2
                + Double(ring) * 0.31
            positions[node.id] = CGPoint(
                x: center.x + cos(angle) * maximumRadiusX * radiusRatio,
                y: center.y + sin(angle) * maximumRadiusY * radiusRatio
            )
        }

        var relaxed = positions
        for _ in 0..<35 {
            for firstIndex in sorted.indices {
                let firstID = sorted[firstIndex].id
                guard var first = relaxed[firstID] else { continue }
                for secondIndex in sorted.index(after: firstIndex)..<sorted.endIndex {
                    let secondID = sorted[secondIndex].id
                    guard var second = relaxed[secondID] else { continue }
                    let dx = second.x - first.x
                    let dy = second.y - first.y
                    let distance = max(1, sqrt(dx * dx + dy * dy))
                    guard distance < Self.nodeSpacing else { continue }
                    let overlap = (Self.nodeSpacing - distance) * 0.3
                    let nx = dx / distance
                    let ny = dy / distance
                    if firstID != sorted[0].id {
                        first.x -= nx * overlap
                        first.y -= ny * overlap
                    }
                    if secondID != sorted[0].id {
                        second.x += nx * overlap
                        second.y += ny * overlap
                    }
                    relaxed[firstID] = first
                    relaxed[secondID] = second
                }
            }
        }

        let margin = CGSize(width: 150, height: 72)
        for (id, point) in relaxed {
            relaxed[id] = CGPoint(
                x: min(max(point.x, margin.width), canvasSize.width - margin.width),
                y: min(max(point.y, margin.height), canvasSize.height - margin.height)
            )
        }
        let bounds = ConstellationViewportMath.renderContentBounds(positions: Array(relaxed.values))
        return ConstellationGraphLayout(
            identity: identity,
            canvasSize: canvasSize,
            canonicalPositions: relaxed,
            positions: relaxed,
            canonicalContentBounds: bounds,
            contentBounds: bounds
        )
    }

    func applying(
        savedPositions: [UUID: CGPoint],
        to layout: ConstellationGraphLayout
    ) -> ConstellationGraphLayout {
        guard !savedPositions.isEmpty else { return layout }
        var positions = layout.canonicalPositions
        let validIDs = Set(positions.keys)
        for (id, point) in savedPositions where validIDs.contains(id) && point.x.isFinite && point.y.isFinite {
            positions[id] = CGPoint(
                x: min(max(point.x, 42), layout.canvasSize.width - 42),
                y: min(max(point.y, 42), layout.canvasSize.height - 42)
            )
        }
        return ConstellationGraphLayout(
            identity: layout.identity,
            canvasSize: layout.canvasSize,
            canonicalPositions: layout.canonicalPositions,
            positions: positions,
            canonicalContentBounds: layout.canonicalContentBounds,
            contentBounds: ConstellationViewportMath.renderContentBounds(positions: Array(positions.values))
        )
    }

    private func logicalCanvasSize(nodeCount: Int) -> CGSize {
        let aspectRatio: CGFloat = 16 / 9
        let area = CGFloat(max(1, nodeCount)) * Self.nodeSpacing * Self.nodeSpacing * 1.1
        return CGSize(
            width: max(Self.minimumCanvasSize.width, sqrt(area * aspectRatio) + 156),
            height: max(Self.minimumCanvasSize.height, sqrt(area / aspectRatio) + 120)
        )
    }
}
