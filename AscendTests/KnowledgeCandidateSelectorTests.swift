import XCTest
@testable import Ascend

final class KnowledgeCandidateSelectorTests: XCTestCase {
    func testCandidateSelectionPrioritizesMatchingTokensAndGraphNeighbors() {
        let nodeSwift = KnowledgeNode(name: "Swift Concurrency", domain: "Swift", isProvisional: false)
        let nodeActor = KnowledgeNode(name: "Actor", domain: "Swift", isProvisional: false)
        let nodeSendable = KnowledgeNode(name: "Sendable", domain: "Swift", isProvisional: false)
        let nodePython = KnowledgeNode(name: "Python Decorator", domain: "Python", isProvisional: false)
        let nodeDjango = KnowledgeNode(name: "Django ORM", domain: "Python", isProvisional: false)

        let otherNodes = (0..<25).map {
            KnowledgeNode(name: "Unrelated Point \($0)", domain: "Other", isProvisional: false)
        }
        let allNodes = [nodeSwift, nodeActor, nodeSendable, nodePython, nodeDjango] + otherNodes

        // Concurrency -> Actor
        let rel = KnowledgeEdge(
            sourceNodeID: nodeSwift.id,
            targetNodeID: nodeActor.id,
            relation: .prerequisite,
            confidence: 1.0
        )

        let activity = CollectedActivity(
            id: UUID(),
            sourceID: UUID(),
            sourceKind: .markdownDirectory,
            timestamp: .now,
            fingerprint: "test-fp",
            title: "Exploring Swift Concurrency in iOS",
            sourceLocator: "notes/swift.md",
            summary: "Deep dive into async await and Concurrency models",
            excerpt: "Swift Concurrency simplifies background execution."
        )

        let candidates = KnowledgeCandidateSelector.selectCandidates(
            for: [activity],
            from: allNodes,
            relations: [rel],
            limit: 20,
            masteryProvider: { _ in 50 }
        )

        XCTAssertEqual(candidates.count, 20)
        let candidateIDs = candidates.map(\.id)
        XCTAssertTrue(candidateIDs.contains(nodeSwift.id), "Direct token match on title/content should be selected")
        XCTAssertTrue(candidateIDs.contains(nodeActor.id), "Graph neighbor of matching node should be selected")
    }

    func testCandidateSelectionReturnsAllWhenBelowLimit() {
        let node1 = KnowledgeNode(name: "A", domain: "D", isProvisional: false)
        let node2 = KnowledgeNode(name: "B", domain: "D", isProvisional: false)
        let candidates = KnowledgeCandidateSelector.selectCandidates(
            for: [],
            from: [node1, node2],
            relations: [],
            limit: 30,
            masteryProvider: { _ in 0 }
        )
        XCTAssertEqual(candidates.count, 2)
    }
}
