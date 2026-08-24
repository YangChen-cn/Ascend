import XCTest
@testable import Ascend

final class AppPageLayoutPolicyTests: XCTestCase {
    func testMinimumWindowDetailUsesSingleColumn() {
        XCTAssertEqual(
            AdaptivePageLayoutPolicy.columnMode(availableWidth: 495),
            .single
        )
    }

    func testDefaultAndWideDetailUseSplitColumns() {
        XCTAssertEqual(
            AdaptivePageLayoutPolicy.columnMode(availableWidth: 1_000),
            .split
        )
        XCTAssertEqual(
            AdaptivePageLayoutPolicy.columnMode(availableWidth: 1_330),
            .split
        )
    }

    func testBoundaryAndMissingSupplementaryContent() {
        let boundary = AdaptivePageLayoutPolicy.minimumPrimaryWidth
            + AdaptivePageLayoutPolicy.supplementaryWidth
            + AdaptivePageLayoutPolicy.spacing

        XCTAssertEqual(
            AdaptivePageLayoutPolicy.columnMode(availableWidth: boundary - 1),
            .single
        )
        XCTAssertEqual(
            AdaptivePageLayoutPolicy.columnMode(availableWidth: boundary),
            .split
        )
        XCTAssertEqual(
            AdaptivePageLayoutPolicy.columnMode(
                availableWidth: 2_000,
                hasSupplementaryContent: false
            ),
            .single
        )
    }
}
