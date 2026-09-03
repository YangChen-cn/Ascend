import XCTest
@testable import Ascend

final class ReviewActivityLocatorTests: XCTestCase {
    func testDirectMarkdownPathResolvesToFile() {
        let url = ReviewActivityLocator.markdownFileURL(from: "/notes/linux/pipe.md")

        XCTAssertEqual(url?.path, "/notes/linux/pipe.md")
    }

    func testRemoteGitLocatorResolvesSpecificMarkdownFile() {
        let url = ReviewActivityLocator.markdownFileURL(
            from: "/repos/learning-note#26e779b:notes/15-two-pipes.md"
        )

        XCTAssertEqual(url?.path, "/repos/learning-note/notes/15-two-pipes.md")
        XCTAssertEqual(url?.lastPathComponent, "15-two-pipes.md")
    }

    func testAggregateCodeAndAssessmentLocatorsAreNotMarkdownNotes() {
        XCTAssertNil(ReviewActivityLocator.markdownFileURL(from: "/repos/learning-note#26e779b:code"))
        XCTAssertNil(ReviewActivityLocator.markdownFileURL(from: "assessment/123"))
    }

    func testRemoteGitLocatorCannotEscapeRepositoryRoot() {
        XCTAssertNil(
            ReviewActivityLocator.markdownFileURL(
                from: "/repos/learning-note#26e779b:../secret.md"
            )
        )
    }
}
