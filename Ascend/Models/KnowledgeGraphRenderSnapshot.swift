import Foundation

struct KnowledgeGraphRenderSnapshot: Sendable, Equatable {
    static let empty = Self(generatedAt: .distantPast, domains: [])

    let generatedAt: Date
    let domains: [ConstellationDomainRenderSnapshot]

    var nodeCount: Int {
        domains.reduce(0) { $0 + $1.nodes.count }
    }

    func domain(named name: String) -> ConstellationDomainRenderSnapshot? {
        domains.first { $0.name == name }
    }

    func node(id: UUID) -> ConstellationNodeSnapshot? {
        domains.lazy.compactMap { domain in domain.nodes.first { $0.id == id } }.first
    }
}

struct ConstellationDomainRenderSnapshot: Identifiable, Sendable, Equatable {
    var id: String { name }

    let name: String
    let nodes: [ConstellationNodeSnapshot]
    let edges: [ConstellationEdgeSnapshot]
    let edgeByID: [UUID: ConstellationEdgeSnapshot]
    let layout: ConstellationGraphLayout
    let edgeGeometryByID: [UUID: ConstellationEdgeGeometry]
    let neighborNodeIDsByNodeID: [UUID: Set<UUID>]
    let incidentEdgeIDsByNodeID: [UUID: Set<UUID>]
    let lineageNodeIDsByNodeID: [UUID: Set<UUID>]
    let lineageEdgeIDsByNodeID: [UUID: Set<UUID>]

    func filteringNodes(matching query: String) -> Self? {
        let visibleNodes = nodes.filter {
            $0.name.localizedStandardContains(query) || name.localizedStandardContains(query)
        }
        guard !visibleNodes.isEmpty else { return nil }
        guard visibleNodes.count != nodes.count else { return self }

        let nodeIDs = Set(visibleNodes.map(\.id))
        let visibleEdges = edges.filter {
            nodeIDs.contains($0.sourceNodeID) && nodeIDs.contains($0.targetNodeID)
        }
        let edgeIDs = Set(visibleEdges.map(\.id))
        let positions = layout.positions.filter { nodeIDs.contains($0.key) }
        let canonicalPositions = layout.canonicalPositions.filter { nodeIDs.contains($0.key) }
        let filteredLayout = ConstellationGraphLayout(
            identity: layout.identity + "|search:" + nodeIDs.map(\.uuidString).sorted().joined(separator: ","),
            canvasSize: layout.canvasSize,
            canonicalPositions: canonicalPositions,
            positions: positions,
            canonicalContentBounds: ConstellationViewportMath.renderContentBounds(positions: Array(canonicalPositions.values)),
            contentBounds: ConstellationViewportMath.renderContentBounds(positions: Array(positions.values))
        )
        return Self(
            name: name,
            nodes: visibleNodes,
            edges: visibleEdges,
            edgeByID: edgeByID.filter { edgeIDs.contains($0.key) },
            layout: filteredLayout,
            edgeGeometryByID: edgeGeometryByID.filter { edgeIDs.contains($0.key) },
            neighborNodeIDsByNodeID: neighborNodeIDsByNodeID.reduce(into: [:]) { result, item in
                guard nodeIDs.contains(item.key) else { return }
                result[item.key] = item.value.intersection(nodeIDs)
            },
            incidentEdgeIDsByNodeID: incidentEdgeIDsByNodeID.reduce(into: [:]) { result, item in
                guard nodeIDs.contains(item.key) else { return }
                result[item.key] = item.value.intersection(edgeIDs)
            },
            lineageNodeIDsByNodeID: lineageNodeIDsByNodeID.reduce(into: [:]) { result, item in
                guard nodeIDs.contains(item.key) else { return }
                result[item.key] = item.value.intersection(nodeIDs)
            },
            lineageEdgeIDsByNodeID: lineageEdgeIDsByNodeID.reduce(into: [:]) { result, item in
                guard nodeIDs.contains(item.key) else { return }
                result[item.key] = item.value.intersection(edgeIDs)
            }
        )
    }
}

struct ConstellationNodeSnapshot: Identifiable, Sendable, Equatable {
    let id: UUID
    let name: String
    let score: Double
    let topologyStatus: NodeTopologyStatus
    let readiness: MasteryReadinessSnapshot?
}

struct ConstellationEdgeSnapshot: Identifiable, Sendable, Equatable {
    let id: UUID
    let sourceNodeID: UUID
    let targetNodeID: UUID
    let relation: KnowledgeRelation
}

struct ConstellationGraphLayout: Sendable, Equatable {
    let identity: String
    let canvasSize: CGSize
    let canonicalPositions: [UUID: CGPoint]
    let positions: [UUID: CGPoint]
    let canonicalContentBounds: CGRect
    let contentBounds: CGRect
}

struct ConstellationEdgeGeometry: Sendable, Equatable {
    let edgeID: UUID
    let sourceNodeID: UUID
    let targetNodeID: UUID
    let relation: KnowledgeRelation
    let source: CGPoint
    let target: CGPoint
    let control: CGPoint

    static func make(edge: ConstellationEdgeSnapshot, positions: [UUID: CGPoint]) -> Self? {
        guard let source = positions[edge.sourceNodeID],
              let target = positions[edge.targetNodeID] else { return nil }
        let dx = target.x - source.x
        let dy = target.y - source.y
        return Self(
            edgeID: edge.id,
            sourceNodeID: edge.sourceNodeID,
            targetNodeID: edge.targetNodeID,
            relation: edge.relation,
            source: source,
            target: target,
            control: CGPoint(
                x: (source.x + target.x) / 2 - dy * 0.08,
                y: (source.y + target.y) / 2 + dx * 0.08
            )
        )
    }
}
