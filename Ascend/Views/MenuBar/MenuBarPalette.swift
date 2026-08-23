import SwiftUI

enum MenuBarPalette {
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.89, green: 0.87, blue: 0.81)
            : Color(red: 0.14, green: 0.14, blue: 0.12)
    }

    static func secondaryInk(_ scheme: ColorScheme) -> Color {
        ink(scheme).opacity(scheme == .dark ? 0.66 : 0.58)
    }

    static func jade(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.32, green: 0.61, blue: 0.53)
            : Color(red: 0.20, green: 0.46, blue: 0.39)
    }

    static func gold(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.73, green: 0.59, blue: 0.36)
            : Color(red: 0.61, green: 0.45, blue: 0.23)
    }

    static func cinnabar(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.72, green: 0.37, blue: 0.32)
            : Color(red: 0.65, green: 0.25, blue: 0.20)
    }

    static func divider(_ scheme: ColorScheme) -> Color {
        ink(scheme).opacity(scheme == .dark ? 0.13 : 0.10)
    }

    static func hoverFill(_ scheme: ColorScheme) -> Color {
        jade(scheme).opacity(scheme == .dark ? 0.12 : 0.075)
    }

    static func hoverStroke(_ scheme: ColorScheme) -> Color {
        jade(scheme).opacity(scheme == .dark ? 0.28 : 0.22)
    }

    static func paperWash(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.075, green: 0.078, blue: 0.072).opacity(0.72)
            : Color(red: 0.97, green: 0.955, blue: 0.91).opacity(0.42)
    }
}
