import Foundation
import Observation

@MainActor
@Observable
final class AppearancePreferences {
    static let shared = AppearancePreferences()

    private enum Key {
        static let appearanceMode = "appearanceMode"
        static let visualTheme = "visualTheme"
    }

    private let defaults: UserDefaults

    var appearanceMode: AppearanceMode {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: Key.appearanceMode)
        }
    }

    var visualTheme: VisualTheme {
        didSet {
            defaults.set(visualTheme.rawValue, forKey: Key.visualTheme)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearanceMode = AppearanceMode(
            rawValue: defaults.string(forKey: Key.appearanceMode) ?? ""
        ) ?? .light
        visualTheme = VisualTheme(
            rawValue: defaults.string(forKey: Key.visualTheme) ?? ""
        ) ?? .defaultTheme
    }
}
