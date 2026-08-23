import XCTest
@testable import Ascend

final class MenuBarWindowPositioningTests: XCTestCase {
    func testOnlyMenuBarClicksBecomeStatusItemAnchors() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 875)

        XCTAssertEqual(
            MenuBarWindowPositioning.statusItemAnchorX(
                mouseLocation: CGPoint(x: 1_200, y: 888),
                screenFrame: screen,
                visibleFrame: visible
            ),
            1_200
        )
        XCTAssertNil(
            MenuBarWindowPositioning.statusItemAnchorX(
                mouseLocation: CGPoint(x: 1_200, y: 850),
                screenFrame: screen,
                visibleFrame: visible
            )
        )
    }

    func testCenteringIsStableAndClampedToVisibleScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 875)

        XCTAssertEqual(
            MenuBarWindowPositioning.centeredOriginX(
                anchorX: 1_200,
                windowWidth: 368,
                visibleFrame: visible
            ),
            1_016
        )
        XCTAssertEqual(
            MenuBarWindowPositioning.centeredOriginX(
                anchorX: 20,
                windowWidth: 368,
                visibleFrame: visible
            ),
            8
        )
    }
}
