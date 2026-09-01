import XCTest
@testable import Ascend

final class DailyDigestPresentationTests: XCTestCase {
    func testPresentationSeparatesNarrativeMetricsAndNextStep() {
        let presentation = DailyDigestPresentation(summary: """
        今日所学：梳理了 fork、exec 与管道通信的关系。
        最重要成长：进程管理 提升 2 点
        真实知识 XP：+20
        待复习：3 项
        完成挑战：实现管道示例
        下一步推荐：继续实践“进程管理”
        """)

        XCTAssertEqual(presentation.learningSummary, "梳理了 fork、exec 与管道通信的关系。")
        XCTAssertEqual(presentation.strongestGrowth, "进程管理 提升 2 点")
        XCTAssertEqual(presentation.xpSummary, "+20")
        XCTAssertEqual(presentation.reviewSummary, "3 项")
        XCTAssertEqual(presentation.challengeSummary, "实现管道示例")
        XCTAssertEqual(presentation.nextStep, "继续实践“进程管理”")
    }

    func testPresentationUsesReadableEmptyFallback() {
        let presentation = DailyDigestPresentation(summary: "")

        XCTAssertNil(presentation.learningSummary)
        XCTAssertTrue(presentation.primaryText.contains("尚无已验证学习结果"))
    }
}
