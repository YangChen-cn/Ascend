import Foundation

struct FocusPreferences: Equatable, Sendable {
    static let focusMinutesKey = "focusSessionMinutes"
    static let breakMinutesKey = "focusBreakMinutes"
    static let longBreakMinutesKey = "focusLongBreakMinutes"
    static let sessionsPerLongBreakKey = "focusSessionsPerLongBreak"
    static let floatsOnTopKey = "focusWindowFloatsOnTop"

    static let defaultFocusMinutes = 25
    static let defaultBreakMinutes = 5
    static let defaultLongBreakMinutes = 15
    static let defaultSessionsPerLongBreak = 4
    static let defaultFloatsOnTop = true

    static let focusMinutesRange = 1...180
    static let breakMinutesRange = 1...60
    static let sessionsPerLongBreakRange = 1...10

    var focusMinutes: Int
    var breakMinutes: Int
    var longBreakMinutes: Int
    var sessionsPerLongBreak: Int
    var floatsOnTop: Bool

    static func current(defaults: UserDefaults = .standard) -> Self {
        Self(
            focusMinutes: (defaults.object(forKey: focusMinutesKey) as? Int ?? defaultFocusMinutes)
                .clamped(to: focusMinutesRange),
            breakMinutes: (defaults.object(forKey: breakMinutesKey) as? Int ?? defaultBreakMinutes)
                .clamped(to: breakMinutesRange),
            longBreakMinutes: (defaults.object(forKey: longBreakMinutesKey) as? Int ?? defaultLongBreakMinutes)
                .clamped(to: breakMinutesRange),
            sessionsPerLongBreak: (defaults.object(forKey: sessionsPerLongBreakKey) as? Int ?? defaultSessionsPerLongBreak)
                .clamped(to: sessionsPerLongBreakRange),
            floatsOnTop: defaults.object(forKey: floatsOnTopKey) as? Bool ?? defaultFloatsOnTop
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(focusMinutes, forKey: Self.focusMinutesKey)
        defaults.set(breakMinutes, forKey: Self.breakMinutesKey)
        defaults.set(longBreakMinutes, forKey: Self.longBreakMinutesKey)
        defaults.set(sessionsPerLongBreak, forKey: Self.sessionsPerLongBreakKey)
        defaults.set(floatsOnTop, forKey: Self.floatsOnTopKey)
    }
}
