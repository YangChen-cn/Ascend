import Foundation

struct KnowledgeEdgeSnapshot: Sendable, Identifiable {
    let id: UUID
    let sourceNodeID: UUID
    let targetNodeID: UUID
    let relation: KnowledgeRelation
    let confidence: Double

    init(
        id: UUID = UUID(),
        sourceNodeID: UUID,
        targetNodeID: UUID,
        relation: KnowledgeRelation,
        confidence: Double
    ) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.relation = relation
        self.confidence = confidence
    }

    init(edge: KnowledgeEdge) {
        self.id = edge.id
        self.sourceNodeID = edge.sourceNodeID
        self.targetNodeID = edge.targetNodeID
        self.relation = edge.relation
        self.confidence = edge.confidence
    }
}

enum NodeTopologyStatus: Sendable, Equatable {
    case blocked(missingPrerequisites: [UUID])
    case readyToLearn(satisfiedPrerequisites: [UUID])
    case progressing
    case mastered

    var title: String {
        switch self {
        case .blocked: "受阻"
        case .readyToLearn: "就绪"
        case .progressing: "研习中"
        case .mastered: "已掌握"
        }
    }
}

struct LearningTopologyEngine: Sendable {
    /// 判定先导知识点是否“已具备/已掌握”的综合掌握度门槛（融会境界起点：60 分）
    var prerequisiteThreshold: Double = 60.0
    /// 判定自身是否“已精通”的掌握度门槛（化用/通达境界：80 分）
    var masteredThreshold: Double = 80.0

    // MARK: - 1. DAG 拓扑成环与合法性检测

    func canAddPrerequisite(
        sourceNodeID: UUID,
        targetNodeID: UUID,
        existingEdges: [KnowledgeEdge]
    ) -> (canAdd: Bool, reason: String?) {
        canAddPrerequisite(
            sourceNodeID: sourceNodeID,
            targetNodeID: targetNodeID,
            existingSnapshots: existingEdges.map(KnowledgeEdgeSnapshot.init)
        )
    }

    func canAddPrerequisite(
        sourceNodeID: UUID,
        targetNodeID: UUID,
        existingSnapshots: [KnowledgeEdgeSnapshot]
    ) -> (canAdd: Bool, reason: String?) {
        // 1. 禁止自环
        if sourceNodeID == targetNodeID {
            return (false, "先导依赖不能指向自身 (Self-loop)")
        }

        let prerequisiteEdges = existingSnapshots.filter { $0.relation == .prerequisite }

        // 2. 禁止重复边
        if prerequisiteEdges.contains(where: { $0.sourceNodeID == sourceNodeID && $0.targetNodeID == targetNodeID }) {
            return (false, "该先导依赖关系已存在")
        }

        // 3. 成环检测：若从 target 出发能沿着先导依赖路径到达 source，则添加 source -> target 必定成环
        if hasPrerequisitePath(from: targetNodeID, to: sourceNodeID, edges: prerequisiteEdges) {
            return (false, "添加该先导依赖会导致循环依赖闭环 (Cycle)")
        }

        return (true, nil)
    }

    func hasPrerequisitePath(
        from startNodeID: UUID,
        to destinationNodeID: UUID,
        edges: [KnowledgeEdgeSnapshot]
    ) -> Bool {
        if startNodeID == destinationNodeID { return true }

        let adjacency = edges.reduce(into: [UUID: [UUID]]()) { result, edge in
            guard edge.relation == .prerequisite else { return }
            result[edge.sourceNodeID, default: []].append(edge.targetNodeID)
        }

        var visited = Set<UUID>()
        var queue = [startNodeID]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == destinationNodeID {
                return true
            }
            if visited.insert(current).inserted {
                let neighbors = adjacency[current] ?? []
                for neighbor in neighbors where !visited.contains(neighbor) {
                    queue.append(neighbor)
                }
            }
        }

        return false
    }

    // MARK: - 2. 先导与后继查询

    func prerequisiteNodeIDs(for nodeID: UUID, in edges: [KnowledgeEdge]) -> [UUID] {
        prerequisiteNodeIDs(for: nodeID, inSnapshots: edges.map(KnowledgeEdgeSnapshot.init))
    }

    func prerequisiteNodeIDs(for nodeID: UUID, inSnapshots edges: [KnowledgeEdgeSnapshot]) -> [UUID] {
        edges
            .filter { $0.relation == .prerequisite && $0.targetNodeID == nodeID }
            .map(\.sourceNodeID)
    }

    func downstreamNodeIDs(for nodeID: UUID, in edges: [KnowledgeEdge]) -> [UUID] {
        downstreamNodeIDs(for: nodeID, inSnapshots: edges.map(KnowledgeEdgeSnapshot.init))
    }

    func downstreamNodeIDs(for nodeID: UUID, inSnapshots edges: [KnowledgeEdgeSnapshot]) -> [UUID] {
        edges
            .filter { $0.relation == .prerequisite && $0.sourceNodeID == nodeID }
            .map(\.targetNodeID)
    }

    // MARK: - 3. 拓扑状态判定

    func status(
        for nodeID: UUID,
        edges: [KnowledgeEdge],
        masteryByNodeID: [UUID: Double]
    ) -> NodeTopologyStatus {
        status(for: nodeID, snapshots: edges.map(KnowledgeEdgeSnapshot.init), masteryByNodeID: masteryByNodeID)
    }

    func status(
        for nodeID: UUID,
        snapshots edges: [KnowledgeEdgeSnapshot],
        masteryByNodeID: [UUID: Double]
    ) -> NodeTopologyStatus {
        let currentMastery = masteryByNodeID[nodeID] ?? 0
        if currentMastery >= masteredThreshold {
            return .mastered
        }

        let prerequisites = prerequisiteNodeIDs(for: nodeID, inSnapshots: edges)
        if prerequisites.isEmpty {
            return currentMastery > 0 ? .progressing : .readyToLearn(satisfiedPrerequisites: [])
        }

        let missing = prerequisites.filter { (masteryByNodeID[$0] ?? 0) < prerequisiteThreshold }
        if !missing.isEmpty {
            return .blocked(missingPrerequisites: missing)
        }

        let satisfied = prerequisites.filter { (masteryByNodeID[$0] ?? 0) >= prerequisiteThreshold }
        if currentMastery < 20 {
            return .readyToLearn(satisfiedPrerequisites: satisfied)
        }
        return .progressing
    }

    func isBlocked(
        for nodeID: UUID,
        edges: [KnowledgeEdge],
        masteryByNodeID: [UUID: Double]
    ) -> Bool {
        if case .blocked = status(for: nodeID, edges: edges, masteryByNodeID: masteryByNodeID) {
            return true
        }
        return false
    }

    func isReadyToLearn(
        for nodeID: UUID,
        edges: [KnowledgeEdge],
        masteryByNodeID: [UUID: Double]
    ) -> Bool {
        if case .readyToLearn = status(for: nodeID, edges: edges, masteryByNodeID: masteryByNodeID) {
            return true
        }
        return false
    }

    func isReadyToLearn(
        for nodeID: UUID,
        snapshots: [KnowledgeEdgeSnapshot],
        masteryByNodeID: [UUID: Double]
    ) -> Bool {
        if case .readyToLearn = status(for: nodeID, snapshots: snapshots, masteryByNodeID: masteryByNodeID) {
            return true
        }
        return false
    }

    func unlockedNextConcepts(
        for sourceNodeID: UUID,
        edges: [KnowledgeEdge],
        masteryByNodeID: [UUID: Double]
    ) -> [UUID] {
        unlockedNextConcepts(for: sourceNodeID, snapshots: edges.map(KnowledgeEdgeSnapshot.init), masteryByNodeID: masteryByNodeID)
    }

    func unlockedNextConcepts(
        for sourceNodeID: UUID,
        snapshots edges: [KnowledgeEdgeSnapshot],
        masteryByNodeID: [UUID: Double]
    ) -> [UUID] {
        let downstream = downstreamNodeIDs(for: sourceNodeID, inSnapshots: edges)
        return downstream.filter { isReadyToLearn(for: $0, snapshots: edges, masteryByNodeID: masteryByNodeID) }
    }
}

// MARK: - PrerequisiteReadinessProviding 适配

struct TopologyReadinessProvider: PrerequisiteReadinessProviding {
    let engine: LearningTopologyEngine
    let edgeSnapshots: [KnowledgeEdgeSnapshot]
    let masteryByNodeID: [UUID: Double]
    let nodeNamesByID: [UUID: String]

    init(
        engine: LearningTopologyEngine,
        edgeSnapshots: [KnowledgeEdgeSnapshot],
        masteryByNodeID: [UUID: Double],
        nodeNamesByID: [UUID: String]
    ) {
        self.engine = engine
        self.edgeSnapshots = edgeSnapshots
        self.masteryByNodeID = masteryByNodeID
        self.nodeNamesByID = nodeNamesByID
    }

    init(
        engine: LearningTopologyEngine,
        edges: [KnowledgeEdge],
        masteryByNodeID: [UUID: Double],
        nodeNamesByID: [UUID: String]
    ) {
        self.init(
            engine: engine,
            edgeSnapshots: edges.map(KnowledgeEdgeSnapshot.init),
            masteryByNodeID: masteryByNodeID,
            nodeNamesByID: nodeNamesByID
        )
    }

    func readiness(for knowledgeNodeID: UUID) -> PrerequisiteReadiness {
        let status = engine.status(for: knowledgeNodeID, snapshots: edgeSnapshots, masteryByNodeID: masteryByNodeID)
        switch status {
        case .blocked(let missing):
            let names = missing.compactMap { nodeNamesByID[$0] }
            let reason = names.isEmpty
                ? "前置知识点尚未掌握"
                : "尚未掌握前置知识：\(names.joined(separator: "、"))"
            return .blocked(reason: reason)
        case .readyToLearn, .progressing, .mastered:
            return .ready
        }
    }
}
