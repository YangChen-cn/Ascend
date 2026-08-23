import XCTest
@testable import Ascend

final class AnalysisBatchPlannerTests: XCTestCase {
    func testTwentyThreeItemsAtTenPerBatchProducesThreeRequests() {
        let ranges = AnalysisBatchPlanner.ranges(itemCount: 23, batchSize: 10)

        XCTAssertEqual(ranges, [0..<10, 10..<20, 20..<23])
    }

    func testEmptyInputProducesNoRequests() {
        XCTAssertTrue(AnalysisBatchPlanner.ranges(itemCount: 0, batchSize: 10).isEmpty)
    }
}
