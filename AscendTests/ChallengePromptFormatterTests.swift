import XCTest
@testable import Ascend

final class ChallengePromptFormatterTests: XCTestCase {
    func testCopiedPromptContainsTaskTargetsRequirementsAndSubmissionGuidance() {
        let challenge = Challenge(
            title: "本地系统监控",
            challengeDescription: "编写守护进程和客户端。",
            estimatedMinutes: 120,
            knowledgeNodeIDs: [],
            requirements: [],
            rewardXP: 300
        )
        let requirement = ChallengeRequirement(
            minimumEvidenceKind: .project,
            minimumIndependence: 1,
            minimumConfidence: 0.8,
            requiredEvidenceCount: 2
        )

        let text = ChallengePromptFormatter().format(
            challenge: challenge,
            requirement: requirement,
            knowledgeNames: ["Unix Domain Socket", "进程监控"]
        )

        XCTAssertTrue(text.contains("# 本地系统监控"))
        XCTAssertTrue(text.contains("编写守护进程和客户端"))
        XCTAssertTrue(text.contains("Unix Domain Socket、进程监控"))
        XCTAssertTrue(text.contains("证据类型至少为 项目应用"))
        XCTAssertTrue(text.contains("选择最近三天的 Git 提交或本地文件"))
    }
}
