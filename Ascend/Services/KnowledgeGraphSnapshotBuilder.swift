import Foundation

@MainActor
struct KnowledgeGraphSnapshotBuilder {
    let topologyEngine: LearningTopologyEngine
    let layoutEngine: ConstellationLayoutEngine
    let layoutStore: ConstellationLayoutStore

    func build(
        nodes: [KnowledgeNode],
        edges: [KnowledgeEdge],
        readinessByNodeID: [UUID: MasteryReadinessSnapshot],
        masteryByNodeID: [UUID: Double],
        domainOrder: [String],
        generatedAt: Date,
        previous: KnowledgeGraphRenderSnapshot,
        topologyIndex suppliedTopologyIndex: LearningTopologyIndex? = nil
    ) -> KnowledgeGraphRenderSnapshot {
        let nodeIDs = Set(nodes.map(\.id))
        let edgeSnapshots = edges.map(KnowledgeEdgeSnapshot.init)
        let topologyIndex = suppliedTopologyIndex ?? topologyEngine.makeIndex(snapshots: edgeSnapshots)
        let statuses = topologyEngine.statuses(
            for: nodeIDs,
            index: topologyIndex,
            masteryByNodeID: masteryByNodeID
        )
        let globalLineages = topologyEngine.lineageHighlightSets(for: nodeIDs, index: topologyIndex)
        let grouped = Dictionary(grouping: nodes, by: \.domain)
        let domainByNodeID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.domain) })
        let renderedEdgesByDomain = edgeSnapshots.reduce(into: [String: [ConstellationEdgeSnapshot]]()) { result, edge in
            guard let sourceDomain = domainByNodeID[edge.sourceNodeID],
                  sourceDomain == domainByNodeID[edge.targetNodeID] else { return }
            result[sourceDomain, default: []].append(
                ConstellationEdgeSnapshot(
                    id: edge.id,
                    sourceNodeID: edge.sourceNodeID,
                    targetNodeID: edge.targetNodeID,
                    relation: edge.relation
                )
            )
        }
        let order = Dictionary(uniqueKeysWithValues: domainOrder.enumerated().map { ($1, $0) })
        let previousByName = Dictionary(uniqueKeysWithValues: previous.domains.map { ($0.name, $0) })

        let domains = grouped.map { domainName, domainNodes in
            makeDomainSnapshot(
                domainName: domainName,
                nodes: domainNodes,
                edges: renderedEdgesByDomain[domainName] ?? [],
                readinessByNodeID: readinessByNodeID,
                statusByNodeID: statuses,
                globalLineages: globalLineages,
                previous: previousByName[domainName]
            )
        }.sorted { lhs, rhs in
            let lhsOrder = order[lhs.name] ?? .max
            let rhsOrder = order[rhs.name] ?? .max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return KnowledgeGraphRenderSnapshot(generatedAt: generatedAt, domains: domains)
    }

    private func makeDomainSnapshot(
        domainName: String,
        nodes: [KnowledgeNode],
        edges: [ConstellationEdgeSnapshot],
        readinessByNodeID: [UUID: MasteryReadinessSnapshot],
        statusByNodeID: [UUID: NodeTopologyStatus],
        globalLineages: [UUID: Set<UUID>],
        previous: ConstellationDomainRenderSnapshot?
    ) -> ConstellationDomainRenderSnapshot {
        let nodeIDs = Set(nodes.map(\.id))
        var degrees: [UUID: Int] = [:]
        var neighbors: [UUID: Set<UUID>] = [:]
        var incidentEdges: [UUID: Set<UUID>] = [:]
        for edge in edges {
            degrees[edge.sourceNodeID, default: 0] += 1
            degrees[edge.targetNodeID, default: 0] += 1
            neighbors[edge.sourceNodeID, default: []].insert(edge.targetNodeID)
            neighbors[edge.targetNodeID, default: []].insert(edge.sourceNodeID)
            incidentEdges[edge.sourceNodeID, default: []].insert(edge.id)
            incidentEdges[edge.targetNodeID, default: []].insert(edge.id)
        }

        let layoutNodes = nodes.map { (id: $0.id, name: $0.name, degree: degrees[$0.id, default: 0]) }
        let identity = layoutEngine.layoutIdentity(domainName: domainName, nodes: layoutNodes, edges: edges)
        let canonicalLayout: ConstellationGraphLayout
        if let previous, previous.layout.identity == identity {
            canonicalLayout = ConstellationGraphLayout(
                identity: identity,
                canvasSize: previous.layout.canvasSize,
                canonicalPositions: previous.layout.canonicalPositions,
                positions: previous.layout.canonicalPositions,
                canonicalContentBounds: previous.layout.canonicalContentBounds,
                contentBounds: previous.layout.canonicalContentBounds
            )
        } else {
            canonicalLayout = layoutEngine.canonicalLayout(identity: identity, nodes: layoutNodes)
        }
        let savedPositions = layoutStore.positions(for: domainName, validNodeIDs: nodeIDs)
        let layout = layoutEngine.applying(savedPositions: savedPositions, to: canonicalLayout)
        let geometryByID = Dictionary(uniqueKeysWithValues: edges.compactMap { edge in
            ConstellationEdgeGeometry.make(edge: edge, positions: layout.positions).map { (edge.id, $0) }
        })

        let lineages = nodeIDs.reduce(into: [UUID: Set<UUID>]()) { result, nodeID in
            result[nodeID] = (globalLineages[nodeID] ?? [nodeID]).intersection(nodeIDs)
        }
        let lineageEdgeIDs = lineages.reduce(into: [UUID: Set<UUID>]()) { result, entry in
            result[entry.key] = Set(edges.compactMap { edge in
                entry.value.contains(edge.sourceNodeID) && entry.value.contains(edge.targetNodeID)
                    ? edge.id
                    : nil
            })
        }
        let nodeSnapshots = nodes.map { node in
            let readiness = readinessByNodeID[node.id]
            return ConstellationNodeSnapshot(
                id: node.id,
                name: node.name,
                score: readiness?.currentComposite ?? 0,
                topologyStatus: statusByNodeID[node.id] ?? .progressing,
                readiness: readiness
            )
        }.sorted {
            if $0.name != $1.name {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.id.uuidString < $1.id.uuidString
        }

        return ConstellationDomainRenderSnapshot(
            name: domainName,
            nodes: nodeSnapshots,
            edges: edges,
            edgeByID: Dictionary(uniqueKeysWithValues: edges.map { ($0.id, $0) }),
            layout: layout,
            edgeGeometryByID: geometryByID,
            neighborNodeIDsByNodeID: neighbors,
            incidentEdgeIDsByNodeID: incidentEdges,
            lineageNodeIDsByNodeID: lineages,
            lineageEdgeIDsByNodeID: lineageEdgeIDs
        )
    }
}
