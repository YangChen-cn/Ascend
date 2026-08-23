import SwiftUI

enum AscendTheme {
    private static var visualTheme: VisualTheme {
        VisualTheme(rawValue: UserDefaults.standard.string(forKey: "visualTheme") ?? "") ?? .xuanqing
    }

    static var jade: Color {
        visualTheme == .xuanqing
            ? Color(red: 0.02, green: 0.34, blue: 0.34)
            : Color(red: 0.02, green: 0.53, blue: 0.43)
    }

    static var cobalt: Color {
        visualTheme == .xuanqing
            ? Color(red: 0.08, green: 0.25, blue: 0.29)
            : Color(red: 0.08, green: 0.35, blue: 0.95)
    }

    static var amber: Color {
        visualTheme == .xuanqing
            ? Color(red: 0.72, green: 0.18, blue: 0.12)
            : Color(red: 0.93, green: 0.48, blue: 0.03)
    }

    static let slate = Color(red: 0.38, green: 0.43, blue: 0.51)

    static func background(for scheme: ColorScheme) -> Color {
        if visualTheme == .xuanqing {
            return scheme == .dark
                ? Color(red: 0.035, green: 0.055, blue: 0.055)
                : Color(red: 0.975, green: 0.955, blue: 0.895)
        }
        return scheme == .dark ? Color(red: 0.035, green: 0.075, blue: 0.13) : .white
    }

    static func surface(for scheme: ColorScheme) -> Color {
        if visualTheme == .xuanqing {
            return scheme == .dark
                ? Color(red: 0.06, green: 0.085, blue: 0.08)
                : Color(red: 0.94, green: 0.91, blue: 0.82)
        }
        return scheme == .dark
            ? Color(red: 0.06, green: 0.11, blue: 0.18)
            : Color(red: 0.965, green: 0.975, blue: 0.985)
    }

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.12) : .black.opacity(0.10)
    }
}
