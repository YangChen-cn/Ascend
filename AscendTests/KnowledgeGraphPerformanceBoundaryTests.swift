import SwiftData
import XCTest
@testable import Ascend

final class KnowledgeGraphPerformanceBoundaryTests: XCTestCase {
    func testBatchTopologyMatchesPerNodeBehaviorAndProtectsAgainstCycles() {
        let engine = LearningTopologyEngine()
        let ids = (0..<12).map { _ in UUID() }
        var edges = (0..<11).map { index in
            KnowledgeEdgeSnapshot(
                sourceNodeID: ids[index],
                targetNodeID: ids[index + 1],
                relation: .prerequisite,
                confidence: 1
            )
        }
        edges.append(
            KnowledgeEdgeSnapshot(
                sourceNodeID: ids[11],
                targetNodeID: ids[3],
                relation: .prerequisite,
                confidence: 1
            )
        )
        edges.append(
            KnowledgeEdgeSnapshot(
                sourceNodeID: ids[0],
                targetNodeID: ids[6],
                relation: .related,
                confidence: 1
            )
        )
        let scores = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, Double($0.offset * 9)) })
        let index = engine.makeIndex(snapshots: edges)
        let statuses = engine.statuses(for: Set(ids), index: index, masteryByNodeID: scores)
        let lineages = engine.lineageHighlightSets(for: Set(ids), index: index)

        for id in ids {
            XCTAssertEqual(
                statuses[id],
                engine.status(for: id, snapshots: edges, masteryByNodeID: scores)
            )
            XCTAssertEqual(
                lineages[id],
                engine.lineageHighlightSet(for: id, index: index)
            )
            XCTAssertTrue(lineages[id]?.contains(id) == true)
        }
        XCTAssertEqual(index.directNeighborNodeIDs[ids[0]], Set([ids[1], ids[6]]))
    }

    func testCanonicalLayoutIsIndependentOfInspectorViewportAndScore() {
        let engine = ConstellationLayoutEngine()
        let nodes = (0..<200).map { index in
            (id: UUID(), name: "节点 \(index)", degree: index % 7)
        }
        var edges = (0..<199).map { index in
            ConstellationEdgeSnapshot(
                id: UUID(),
                sourceNodeID: nodes[index].id,
                targetNodeID: nodes[index + 1].id,
                relation: .prerequisite
            )
        }
        edges.append(contentsOf: (0..<101).map { index in
            ConstellationEdgeSnapshot(
                id: UUID(),
                sourceNodeID: nodes[index].id,
                targetNodeID: nodes[(index + 17) % nodes.count].id,
                relation: .related
            )
        })
        let identity = engine.layoutIdentity(domainName: "压力域", nodes: nodes, edges: edges)
        let layout = engine.canonicalLayout(identity: identity, nodes: nodes)

        for width in stride(from: 1_200.0, through: 700.0, by: -10) {
            _ = ConstellationViewportMath.viewportTransform(
                logicalCanvasSize: layout.canvasSize,
                contentBounds: layout.contentBounds,
                viewportSize: CGSize(width: width, height: 640),
                userZoomScale: 1,
                proposedUserPanOffset: .zero
            )
        }
        for width in stride(from: 700.0, through: 1_200.0, by: 10) {
            _ = ConstellationViewportMath.viewportTransform(
                logicalCanvasSize: layout.canvasSize,
                contentBounds: layout.contentBounds,
                viewportSize: CGSize(width: width, height: 640),
                userZoomScale: 1.2,
                proposedUserPanOffset: CGSize(width: 30, height: -10)
            )
        }

        XCTAssertEqual(layout.identity, identity)
        XCTAssertEqual(layout.canonicalPositions.count, 200)
        XCTAssertEqual(layout.positions, layout.canonicalPositions)
        XCTAssertEqual(edges.count, 300)
    }

    @MainActor
    func testScoreRefreshReusesLayoutWhileTopologyChangeInvalidatesIt() {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let store = ConstellationLayoutStore(defaults: defaults)
        let builder = KnowledgeGraphSnapshotBuilder(
            topologyEngine: LearningTopologyEngine(),
            layoutEngine: ConstellationLayoutEngine(),
            layoutStore: store
        )
        let first = KnowledgeNode(name: "A", domain: "领域")
        let second = KnowledgeNode(name: "B", domain: "领域")
        let nodes = [first, second]
        let firstReadiness = readiness(id: first.id, score: 20)
        let secondReadiness = readiness(id: second.id, score: 40)
        let initial = builder.build(
            nodes: nodes,
            edges: [],
            readinessByNodeID: [first.id: firstReadiness, second.id: secondReadiness],
            masteryByNodeID: [first.id: 20, second.id: 40],
            domainOrder: ["领域"],
            generatedAt: Date(timeIntervalSince1970: 1),
            previous: .empty
        )
        let scoreOnly = builder.build(
            nodes: nodes,
            edges: [],
            readinessByNodeID: [first.id: readiness(id: first.id, score: 70), second.id: secondReadiness],
            masteryByNodeID: [first.id: 70, second.id: 40],
            domainOrder: ["领域"],
            generatedAt: Date(timeIntervalSince1970: 2),
            previous: initial
        )

        XCTAssertEqual(initial.domains[0].layout.identity, scoreOnly.domains[0].layout.identity)
        XCTAssertEqual(initial.domains[0].layout.canonicalPositions, scoreOnly.domains[0].layout.canonicalPositions)
        XCTAssertNotEqual(initial.domains[0].nodes[0].score, scoreOnly.domains[0].nodes[0].score)

        let edge = KnowledgeEdge(
            sourceNodeID: first.id,
            targetNodeID: second.id,
            relation: .prerequisite,
            confidence: 1
        )
        let topologyChanged = builder.build(
            nodes: nodes,
            edges: [edge],
            readinessByNodeID: [first.id: firstReadiness, second.id: secondReadiness],
            masteryByNodeID: [first.id: 20, second.id: 40],
            domainOrder: ["领域"],
            generatedAt: Date(timeIntervalSince1970: 3),
            previous: scoreOnly
        )
        XCTAssertNotEqual(scoreOnly.domains[0].layout.identity, topologyChanged.domains[0].layout.identity)
    }

    @MainActor
    func testCrossDomainTopologyIsGlobalButRenderedEdgesAreDomainLocal() {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let source = KnowledgeNode(name: "跨域前置", domain: "甲")
        let target = KnowledgeNode(name: "跨域下游", domain: "乙")
        let edge = KnowledgeEdge(
            sourceNodeID: source.id,
            targetNodeID: target.id,
            relation: .prerequisite,
            confidence: 1
        )
        let snapshot = KnowledgeGraphSnapshotBuilder(
            topologyEngine: LearningTopologyEngine(),
            layoutEngine: ConstellationLayoutEngine(),
            layoutStore: ConstellationLayoutStore(defaults: defaults)
        ).build(
            nodes: [source, target],
            edges: [edge],
            readinessByNodeID: [
                source.id: readiness(id: source.id, score: 20),
                target.id: readiness(id: target.id, score: 0)
            ],
            masteryByNodeID: [source.id: 20, target.id: 0],
            domainOrder: ["甲", "乙"],
            generatedAt: .now,
            previous: .empty
        )

        XCTAssertTrue(snapshot.domains.allSatisfy(\.edges.isEmpty))
        guard case .blocked(let missing)? = snapshot.node(id: target.id)?.topologyStatus else {
            return XCTFail("跨领域前置仍应阻塞下游节点")
        }
        XCTAssertEqual(missing, [source.id])
        XCTAssertEqual(snapshot.domain(named: "甲")?.lineageNodeIDsByNodeID[source.id], Set([source.id]))
    }

    @MainActor
    func testDraggedPositionPersistsRestoresAndResetsWithoutSwiftData() {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let store = ConstellationLayoutStore(defaults: defaults)
        let nodeID = UUID()
        let point = CGPoint(x: 320, y: 180)

        store.save(position: point, nodeID: nodeID, domainName: "领域")
        XCTAssertEqual(store.positions(for: "领域", validNodeIDs: [nodeID])[nodeID], point)
        XCTAssertTrue(store.positions(for: "领域", validNodeIDs: [UUID()]).isEmpty)

        store.reset(domainName: "领域")
        XCTAssertTrue(store.positions(for: "领域", validNodeIDs: [nodeID]).isEmpty)
    }

    @MainActor
    func testTargetedCompositeMatchesFullComposite() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: AscendSchemaV9.self),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let nodes = (0..<3).map { KnowledgeNode(name: "N\($0)", domain: "D") }
        for (index, node) in nodes.enumerated() {
            container.mainContext.insert(node)
            container.mainContext.insert(
                MasteryState(
                    knowledgeNodeID: node.id,
                    vector: MasteryVector(
                        exposure: Double(index * 10 + 10),
                        understanding: 20,
                        practice: 30,
                        retention: 40,
                        autonomy: 50
                    )
                )
            )
        }
        try container.mainContext.save()
        let state = AppState(modelContainer: container)
        state.reload()
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let full = state.currentCompositeByNodeID(now: now)
        let targetIDs = Set(nodes.prefix(2).map(\.id))
        let targeted = state.currentCompositeByNodeID(for: targetIDs, now: now)

        XCTAssertEqual(targeted.count, 2)
        for id in targetIDs { XCTAssertEqual(targeted[id], full[id]) }
    }

    private let defaultsSuiteName = "KnowledgeGraphPerformanceBoundaryTests"

    private func isolatedDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }

    private func readiness(id: UUID, score: Double) -> MasteryReadinessSnapshot {
        let vector = MasteryVector(
            exposure: score,
            understanding: score,
            practice: score,
            retention: score,
            autonomy: score
        )
        return MasteryReadinessSnapshot(
            knowledgeNodeID: id,
            historicalVector: vector,
            currentVector: vector,
            historicalStage: MasteryStage.stage(for: score),
            currentStage: MasteryStage.stage(for: score)
        )
    }
}
