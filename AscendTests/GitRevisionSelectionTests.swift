import XCTest
@testable import Ascend

final class GitRevisionSelectionTests: XCTestCase {
    func testIncrementalSelectionUsesEntireCursorToHeadRangeWithoutCommitLimit() {
        let selection = GitRevisionSelection.make(
            headSHA: "head-sha",
            lastCursor: "cursor-sha",
            lastScannedAt: .distantPast,
            cursorIsAncestor: true
        )

        XCTAssertEqual(selection, .incremental(range: "cursor-sha..head-sha"))
        XCTAssertTrue(selection.logArguments.contains("cursor-sha..head-sha"))
        XCTAssertFalse(selection.logArguments.contains { $0.contains("max-count") })
    }

    func testInitialSelectionUsesBoundedBootstrapWhenCursorIsMissingOrInvalid() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let selection = GitRevisionSelection.make(
            headSHA: "head-sha",
            lastCursor: "rewritten-away",
            lastScannedAt: nil,
            cursorIsAncestor: false,
            now: now
        )

        guard case .initial(let headSHA, let since, let maximumCommitCount) = selection else {
            return XCTFail("Expected initial scan selection")
        }
        XCTAssertEqual(headSHA, "head-sha")
        XCTAssertEqual(maximumCommitCount, 200)
        XCTAssertEqual(since, now.addingTimeInterval(-7 * 86_400))
    }
}
