import XCTest
@testable import Ascend

final class AssessmentPackagePolicyTests: XCTestCase {
    func testValidPackageKeepsAtMostEightItems() throws {
        let request = request()
        let package = AssessmentPackage(
            knowledgeNodeID: request.knowledgeNodeID,
            items: (0..<9).map { item(index: $0, activityID: request.sourceMaterials[0].activityID, knowledgeNodeID: request.knowledgeNodeID) }
        )

        let validated = try AssessmentPackagePolicy.validated(package, request: request)
        XCTAssertEqual(validated.items.count, 8)
    }

    func testWrongNodeAndFewerThanFiveValidItemsRejectEntirePackage() {
        let request = request()
        let wrongNode = AssessmentPackage(knowledgeNodeID: UUID(), items: [])
        XCTAssertThrowsError(try AssessmentPackagePolicy.validated(wrongNode, request: request))

        let duplicate = item(index: 0, activityID: request.sourceMaterials[0].activityID, knowledgeNodeID: request.knowledgeNodeID)
        let tooSmall = AssessmentPackage(
            knowledgeNodeID: request.knowledgeNodeID,
            items: [duplicate, duplicate, duplicate, duplicate, duplicate]
        )
        XCTAssertThrowsError(try AssessmentPackagePolicy.validated(tooSmall, request: request)) { error in
            XCTAssertEqual(error as? AssessmentPackagePolicy.ValidationError, .insufficientValidItems(1))
        }
    }

    func testInvalidAnswerRangeAndUnknownSourceAreRemoved() {
        let request = request()
        let invalidRange = AssessmentPackage.Item(
            knowledgeNodeID: request.knowledgeNodeID,
            tier: .foundational,
            stem: "invalid range",
            answerOptions: ["A", "B", "C", "D"],
            correctAnswerIndex: 4,
            reasoningPrompt: "why",
            reasoningOptions: ["1", "2", "3", "4"],
            correctReasoningIndex: 0,
            explanation: "explanation",
            misconceptionTags: [],
            sourceActivityIDs: []
        )
        let unknownSource = item(index: 99, activityID: UUID(), knowledgeNodeID: request.knowledgeNodeID)
        let valid = (0..<4).map { item(index: $0, activityID: request.sourceMaterials[0].activityID, knowledgeNodeID: request.knowledgeNodeID) }
        let package = AssessmentPackage(
            knowledgeNodeID: request.knowledgeNodeID,
            items: valid + [invalidRange, unknownSource]
        )
        XCTAssertThrowsError(try AssessmentPackagePolicy.validated(package, request: request))
    }

    private func request() -> AssessmentRequest {
        AssessmentRequest(
            knowledgeNodeID: UUID(),
            knowledgeName: "Swift actor",
            domain: "Swift",
            currentMasteryProbability: nil,
            kind: .baseline,
            sourceMaterials: [
                .init(activityID: UUID(), title: "note", summary: "summary", excerpt: "excerpt")
            ]
        )
    }

    private func item(index: Int, activityID: UUID, knowledgeNodeID: UUID) -> AssessmentPackage.Item {
        AssessmentPackage.Item(
            knowledgeNodeID: knowledgeNodeID,
            tier: AssessmentTier.allCases[index % AssessmentTier.allCases.count],
            stem: "stem \(index)",
            answerOptions: ["A\(index)", "B\(index)", "C\(index)", "D\(index)"],
            correctAnswerIndex: 0,
            reasoningPrompt: "reason \(index)",
            reasoningOptions: ["R1-\(index)", "R2-\(index)", "R3-\(index)", "R4-\(index)"],
            correctReasoningIndex: 1,
            explanation: "explanation \(index)",
            misconceptionTags: ["tag"],
            sourceActivityIDs: [activityID]
        )
    }
}
