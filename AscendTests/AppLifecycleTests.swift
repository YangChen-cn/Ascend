import AppKit
import XCTest
@testable import Ascend

@MainActor
final class AppLifecycleTests: XCTestCase {
    func testTestHostIsDetectedBeforeStartingProductionAutomation() {
        XCTAssertTrue(AppRuntime.isRunningTests)
    }

    func testClosingLastWindowKeepsAgentApplicationRunning() {
        let delegate = AppDelegate()

        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }

    func testAutomationStartsWhenHandlerArrivesAfterApplicationDidFinishLaunching() async {
        let delegate = AppDelegate()
        let started = expectation(description: "automation started")
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        delegate.startAutomation = {
            started.fulfill()
        }

        await fulfillment(of: [started], timeout: 1)
    }

    func testAutomationStartsOnlyOnceWhenHandlerIsReassigned() async {
        let delegate = AppDelegate()
        let started = expectation(description: "automation started once")
        started.expectedFulfillmentCount = 1
        started.assertForOverFulfill = true
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        delegate.startAutomation = { started.fulfill() }
        delegate.startAutomation = { started.fulfill() }

        await fulfillment(of: [started], timeout: 1)
    }
}
