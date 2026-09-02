import XCTest
@testable import Ascend

final class ChallengeEvidenceReviewPolicyTests: XCTestCase {
    func testPassingRequiresExplicitPassAndHighConfidence() {
        XCTAssertTrue(ChallengeEvidenceReviewPolicy.isPassing(.init(passed: true, confidence: 0.8, summary: "覆盖", failureReasons: [])))
        XCTAssertFalse(ChallengeEvidenceReviewPolicy.isPassing(.init(passed: true, confidence: 0.79, summary: "覆盖", failureReasons: [])))
        XCTAssertFalse(ChallengeEvidenceReviewPolicy.isPassing(.init(passed: false, confidence: 1, summary: "不足", failureReasons: ["缺测试"])))
    }

    func testFailedReviewGetsActionableFallbackReason() {
        let review = ChallengeEvidenceReviewPolicy.normalized(.init(passed: false, confidence: -0.2, summary: "", failureReasons: []))
        XCTAssertEqual(review.confidence, 0)
        XCTAssertFalse(review.failureReasons.isEmpty)
    }

    func testAuditExcerptPrioritizesPipeFileInsteadOfOnlyFirstMakefile() {
        let diff = """
        diff --git a/Makefile b/Makefile
        +all: app
        diff --git a/daemon.c b/daemon.c
        +int fd[2];
        +pipe(fd);
        +if (fork() == 0) { close(fd[1]); }
        diff --git a/signal.c b/signal.c
        +sigaction(SIGTERM, &action, NULL);
        """
        let excerpt = ChallengeEvidenceExcerptLoader.makeExcerpt(
            from: diff,
            focusTexts: ["Linux 进程间通信（IPC）", "管道"]
        )
        XCTAssertTrue(excerpt.contains("daemon.c"))
        XCTAssertTrue(excerpt.contains("pipe(fd)"))
    }
}
