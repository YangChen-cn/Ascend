import XCTest
@testable import Ascend

@MainActor
final class AppearancePreferencesTests: XCTestCase {
    func testDefaultsUseXuanqingAndLightMode() throws {
        let defaults = try makeDefaults()
        let preferences = AppearancePreferences(defaults: defaults)

        XCTAssertEqual(preferences.visualTheme, .xuanqing)
        XCTAssertEqual(preferences.appearanceMode, .light)
    }

    func testChangesPersistAcrossInstances() throws {
        let defaults = try makeDefaults()
        let preferences = AppearancePreferences(defaults: defaults)

        preferences.visualTheme = .contemporary
        preferences.appearanceMode = .dark

        let restored = AppearancePreferences(defaults: defaults)
        XCTAssertEqual(restored.visualTheme, .contemporary)
        XCTAssertEqual(restored.appearanceMode, .dark)
    }

    func testInvalidStoredValuesFallBackSafely() throws {
        let defaults = try makeDefaults()
        defaults.set("missing-theme", forKey: "visualTheme")
        defaults.set("missing-mode", forKey: "appearanceMode")

        let preferences = AppearancePreferences(defaults: defaults)

        XCTAssertEqual(preferences.visualTheme, .xuanqing)
        XCTAssertEqual(preferences.appearanceMode, .light)
    }

    func testThemeChangeNotifiesObservationSubscribers() async throws {
        let defaults = try makeDefaults()
        let preferences = AppearancePreferences(defaults: defaults)
        let notification = expectation(description: "visual theme observer notified")

        withObservationTracking {
            _ = preferences.visualTheme
        } onChange: {
            notification.fulfill()
        }

        preferences.visualTheme = .contemporary

        await fulfillment(of: [notification], timeout: 1)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "AppearancePreferencesTests.\(UUID().uuidString)"
        return try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }
}
