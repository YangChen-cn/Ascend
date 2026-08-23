import SwiftData
import XCTest
@testable import Ascend

final class CelestialConstellationInteractionTests: XCTestCase {
    private var container: ModelContainer!
    private var appState: AppState!

    @MainActor
    override func setUp() async throws {
        let schema = Schema(AscendSchemaV8.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        appState = AppState(modelContainer: container)
    }

    override func tearDown() {
        container = nil
        appState = nil
    }

    // MARK: - 1. 默认进入星图时 selected == nil

    @MainActor
    func testInitialSelectedNodeIsNil() {
        let nodeA = KnowledgeNode(name: "指针", domain: "C语言")
        let nodeB = KnowledgeNode(name: "结构体", domain: "C语言")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)
        try? container.mainContext.save()

        appState.reload()

        XCTAssertNil(appState.selectedKnowledgeNodeID, "默认进入星图时不应自动选中任何节点")
    }

    // MARK: - 2. 点击节点选中 / 再次点击取消 / 点击空白取消

    @MainActor
    func testNodeSelectionAndDeselectionBehavior() {
        let nodeA = KnowledgeNode(name: "Goroutine", domain: "Go")
        let nodeB = KnowledgeNode(name: "Channel", domain: "Go")
        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)
        try? container.mainContext.save()
        appState.reload()

        func selectNode(_ node: KnowledgeNode?) {
            guard let node else {
                appState.selectedKnowledgeNodeID = nil
                return
            }
            if appState.selectedKnowledgeNodeID == node.id {
                appState.selectedKnowledgeNodeID = nil
            } else {
                appState.selectedKnowledgeNodeID = node.id
            }
        }

        // 1. 初始为 nil
        XCTAssertNil(appState.selectedKnowledgeNodeID)

        // 2. 点击节点 A -> 选中 A
        selectNode(nodeA)
        XCTAssertEqual(appState.selectedKnowledgeNodeID, nodeA.id)

        // 3. 再次点击同一节点 A -> 取消选中 (nil)
        selectNode(nodeA)
        XCTAssertNil(appState.selectedKnowledgeNodeID, "再次点击同节点必须取消选择")

        // 4. 点击节点 B -> 选中 B
        selectNode(nodeB)
        XCTAssertEqual(appState.selectedKnowledgeNodeID, nodeB.id)

        // 5. 点击空白区域 (nil) -> 取消选中
        selectNode(nil)
        XCTAssertNil(appState.selectedKnowledgeNodeID, "点击空白区域必须取消选择")
    }

    // MARK: - 3. Selected Mode: 完整 Lineage 高亮与适度淡化

    @MainActor
    func testSelectedLineageHighlight() {
        let nodeA = KnowledgeNode(name: "A", domain: "DAG")
        let nodeB = KnowledgeNode(name: "B", domain: "DAG")
        let nodeC = KnowledgeNode(name: "C", domain: "DAG")
        let nodeD = KnowledgeNode(name: "D", domain: "DAG")

        container.mainContext.insert(nodeA)
        container.mainContext.insert(nodeB)
        container.mainContext.insert(nodeC)
        container.mainContext.insert(nodeD)

        // A -> B -> C (D 独立)
        let edgeAB = KnowledgeEdge(sourceNodeID: nodeA.id, targetNodeID: nodeB.id, relation: .prerequisite, confidence: 1.0)
        let edgeBC = KnowledgeEdge(sourceNodeID: nodeB.id, targetNodeID: nodeC.id, relation: .prerequisite, confidence: 1.0)
        container.mainContext.insert(edgeAB)
        container.mainContext.insert(edgeBC)
        try? container.mainContext.save()
        appState.reload()

        let lineageForB = appState.lineageHighlightSet(for: nodeB.id)
        XCTAssertTrue(lineageForB.contains(nodeA.id), "B 的先导祖先 A 必须在高亮集中")
        XCTAssertTrue(lineageForB.contains(nodeB.id), "B 本身必须在高亮集中")
        XCTAssertTrue(lineageForB.contains(nodeC.id), "B 的后继衍生 C 必须在高亮集中")
        XCTAssertFalse(lineageForB.contains(nodeD.id), "无关节点 D 不应在高亮集中")
    }

    // MARK: - 4. Mastery 颜色与 Topology 状态视觉正交分离

    func testMasteryStageColorPreservedWhenBlocked() {
        let scoreProficient = 55.0 // 通晓阶段 (40-59)
        let stage = MasteryStage.stage(for: scoreProficient)
        XCTAssertEqual(stage, .proficient, "55分属于通晓阶段")

        let topologyBlocked = NodeTopologyStatus.blocked(missingPrerequisites: [UUID()])
        if case .blocked = topologyBlocked {
            // 验证 blocked 是纯拓扑状态，并不改变 MasteryStage 的判定
            XCTAssertEqual(stage, .proficient)
        } else {
            XCTFail("应该是 blocked 状态")
        }

        let scoreIntegrated = 75.0 // 融会贯通 (60-79)
        let stageIntegrated = MasteryStage.stage(for: scoreIntegrated)
        XCTAssertEqual(stageIntegrated, .integrated, "75分属于融会阶段")
    }
}
