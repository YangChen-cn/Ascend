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

    func testAuditExcerptIncludesLateMatchingWindowsFromLongRelevantFile() {
        let filler = (0..<180).map { "+close(request_pipe[\($0 % 2)]); /* filler \($0) */" }.joined(separator: "\n")
        let diff = """
        diff --git a/monitor_two_pipe.c b/monitor_two_pipe.c
        +pipe(request_pipe);
        \(filler)
        +child_pid = waitpid(child_pid, &status, 0);
        +if (child_pid < 0 && errno == EINTR) { retry(); }
        """
        let excerpt = ChallengeEvidenceExcerptLoader.makeExcerpt(
            from: diff,
            focusTexts: ["双向管道", "waitpid 处理 EINTR"]
        )
        XCTAssertTrue(excerpt.contains("pipe(request_pipe)"))
        XCTAssertTrue(excerpt.contains("waitpid(child_pid"))
        XCTAssertTrue(excerpt.contains("errno == EINTR"))
    }

    func testGitCommitLocationSupportsRemoteAggregateAndLocalCommit() throws {
        let remote = SubmittedPerformanceEvidence(
            title: "远端代码",
            sourceLocator: "/tmp/repository#26e779b:code",
            contentChangeHash: "remote",
            sourceKind: .remoteGitRepository,
            occurredAt: .now
        )
        let local = SubmittedPerformanceEvidence(
            title: "本地提交",
            sourceLocator: "/tmp/repository#a53d72d37263",
            contentChangeHash: "local",
            sourceKind: .gitRepository,
            occurredAt: .now
        )

        let remoteLocation = try XCTUnwrap(ChallengeEvidenceExcerptLoader.gitCommitLocation(for: remote))
        XCTAssertEqual(remoteLocation.repositoryPath, "/tmp/repository")
        XCTAssertEqual(remoteLocation.commit, "26e779b")
        let localLocation = try XCTUnwrap(ChallengeEvidenceExcerptLoader.gitCommitLocation(for: local))
        XCTAssertEqual(localLocation.repositoryPath, "/tmp/repository")
        XCTAssertEqual(localLocation.commit, "a53d72d37263")
    }

    func testGitCommitLocationRejectsSingleMarkdownActivity() {
        let markdown = SubmittedPerformanceEvidence(
            title: "单篇笔记",
            sourceLocator: "/tmp/repository#26e779b:README.md",
            contentChangeHash: "markdown",
            sourceKind: .remoteGitRepository,
            occurredAt: .now
        )

        XCTAssertNil(ChallengeEvidenceExcerptLoader.gitCommitLocation(for: markdown))
    }

    func testSelectedFileExcerptDeclaresStrictFileScope() {
        let excerpt = ChallengeEvidenceExcerptLoader.makeExcerpt(
            from: "diff --git a/test/pipe.c b/test/pipe.c\n+pipe(fd);",
            focusTexts: ["管道"],
            selectedFileCount: 1
        )

        XCTAssertTrue(excerpt.contains("用户明确选择 1 个文件"))
        XCTAssertTrue(excerpt.contains("仅核验所选文件"))
    }

    func testSingleSelectedFileIsNotSubjectToLegacySevenThousandCharacterCap() {
        let filler = String(repeating: "+int ordinary_value = 1;\n", count: 360)
        let diff = "diff --git a/test/monitor.c b/test/monitor.c\n\(filler)+int required_tail_marker = 42;"

        let excerpt = ChallengeEvidenceExcerptLoader.makeExcerpt(
            from: diff,
            focusTexts: ["没有命中的挑战词"],
            selectedFileCount: 1
        )

        XCTAssertGreaterThan(diff.count, 7_000)
        XCTAssertTrue(excerpt.contains("required_tail_marker"))
    }
}
