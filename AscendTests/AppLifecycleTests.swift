import AppKit
import XCTest
@testable import Ascend

@MainActor
final class AppLifecycleTests: XCTestCase {
    func testClosingLastWindowKeepsAgentApplicationRunning() {
        let delegate = AppDelegate()

        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }
}
