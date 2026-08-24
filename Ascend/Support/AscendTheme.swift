import SwiftUI

@MainActor
enum AscendTheme {
    enum Spacing {
        static let compact: CGFloat = 6
        static let related: CGFloat = 10
        static let section: CGFloat = 16
        static let page: CGFloat = 20
    }

    enum Radius {
        static let control: CGFloat = 8
        static let surface: CGFloat = 12
        static let emphasized: CGFloat = 14
    }

    static let pageHorizontalPadding: CGFloat = 20
    static let pageVerticalPadding: CGFloat = 18

    static var currentTheme: VisualTheme {
        AppearancePreferences.shared.visualTheme
    }

    static var isXuanqing: Bool {
        currentTheme == .xuanqing
    }

    // MARK: - 主色调
    static var jade: Color {
        isXuanqing
            ? Color(red: 0.12, green: 0.56, blue: 0.44)
            : Color(red: 0.10, green: 0.43, blue: 0.83)
    }

    static var deepJade: Color {
        isXuanqing
            ? Color(red: 0.03, green: 0.38, blue: 0.32)
            : Color(red: 0.05, green: 0.28, blue: 0.62)
    }

    static var gold: Color {
        isXuanqing
            ? Color(red: 0.72, green: 0.51, blue: 0.22)
            : Color(red: 0.92, green: 0.62, blue: 0.15)
    }

    static var cobalt: Color {
        isXuanqing
            ? jade
            : Color(red: 0.10, green: 0.43, blue: 0.83)
    }

    static var amber: Color {
        isXuanqing
            ? Color(red: 0.92, green: 0.32, blue: 0.24)
            : Color(red: 0.94, green: 0.42, blue: 0.12)
    }

    // 朱砂色：典雅纯正的朱红，用于书签、印记与重点标识
    static var cinnabar: Color {
        isXuanqing
            ? Color(red: 0.88, green: 0.28, blue: 0.22)
            : Color(red: 0.85, green: 0.24, blue: 0.20)
    }

    // 墨玉色：深沉内敛的墨绿玄色
    static var inkJade: Color {
        isXuanqing
            ? Color(red: 0.08, green: 0.22, blue: 0.18)
            : Color(red: 0.18, green: 0.21, blue: 0.26)
    }

    static var frost: Color {
        isXuanqing
            ? Color(red: 0.92, green: 0.96, blue: 0.98)
            : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    static let slate = Color(red: 0.45, green: 0.52, blue: 0.58)

    // MARK: - 渐变体系
    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: isXuanqing
                ? [Color(red: 1.0, green: 0.86, blue: 0.45), Color(red: 0.88, green: 0.58, blue: 0.16)]
                : [Color(red: 0.98, green: 0.75, blue: 0.25), Color(red: 0.92, green: 0.55, blue: 0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var jadeGradient: LinearGradient {
        LinearGradient(
            colors: isXuanqing
                ? [Color(red: 0.25, green: 0.88, blue: 0.68), Color(red: 0.05, green: 0.58, blue: 0.42)]
                : [Color(red: 0.28, green: 0.60, blue: 0.96), Color(red: 0.08, green: 0.36, blue: 0.76)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var astralGradient: LinearGradient {
        LinearGradient(
            colors: isXuanqing
                ? [Color(red: 0.38, green: 0.78, blue: 0.98), Color(red: 0.10, green: 0.45, blue: 0.78)]
                : [Color(red: 0.25, green: 0.58, blue: 0.95), Color(red: 0.10, green: 0.35, blue: 0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cinnabarGradient: LinearGradient {
        LinearGradient(
            colors: isXuanqing
                ? [Color(red: 0.98, green: 0.42, blue: 0.32), Color(red: 0.82, green: 0.18, blue: 0.15)]
                : [Color(red: 0.95, green: 0.35, blue: 0.25), Color(red: 0.85, green: 0.20, blue: 0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - 背景与表面材质
    static func background(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.032, green: 0.050, blue: 0.058) // 太虚玄渊
                : Color(red: 0.978, green: 0.965, blue: 0.925) // 素绢云宣
        } else {
            return scheme == .dark
                ? Color(red: 0.065, green: 0.080, blue: 0.110) // 现代深空灰
                : Color(red: 0.975, green: 0.980, blue: 0.988) // 纯净淡灰底
        }
    }

    static func surface(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.065, green: 0.095, blue: 0.110) // 墨玉毛玻璃
                : Color(red: 0.995, green: 0.988, blue: 0.965) // 羊脂温玉白
        } else {
            return scheme == .dark
                ? Color(red: 0.110, green: 0.135, blue: 0.175) // 现代深色卡片
                : Color.white // 现代纯白卡片
        }
    }

    static func elevatedSurface(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.075, green: 0.115, blue: 0.115)
                : Color(red: 0.992, green: 0.982, blue: 0.945)
        }
        return scheme == .dark
            ? Color(red: 0.13, green: 0.15, blue: 0.19)
            : Color.white
    }

    static func subtleSurface(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color.white.opacity(0.035)
                : inkJade.opacity(0.035)
        }
        return Color.primary.opacity(scheme == .dark ? 0.055 : 0.035)
    }

    static func separator(for scheme: ColorScheme) -> Color {
        isXuanqing
            ? (scheme == .dark ? Color.white.opacity(0.11) : inkJade.opacity(0.13))
            : Color.primary.opacity(scheme == .dark ? 0.14 : 0.10)
    }

    static func hoverSurface(for scheme: ColorScheme) -> Color {
        jade.opacity(scheme == .dark ? 0.12 : 0.075)
    }

    static func selectedSurface(for scheme: ColorScheme) -> Color {
        jade.opacity(scheme == .dark ? 0.20 : 0.12)
    }

    static func disabledSurface(for scheme: ColorScheme) -> Color {
        Color.primary.opacity(scheme == .dark ? 0.045 : 0.03)
    }

    static func warningSurface(for scheme: ColorScheme) -> Color {
        cinnabar.opacity(scheme == .dark ? 0.16 : 0.09)
    }

    static func border(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.20, green: 0.45, blue: 0.45).opacity(0.35)
                : Color(red: 0.70, green: 0.65, blue: 0.55).opacity(0.30)
        } else {
            return scheme == .dark
                ? Color.white.opacity(0.10)
                : Color(red: 0.88, green: 0.90, blue: 0.93)
        }
    }

    static func goldenBorder(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.95, green: 0.75, blue: 0.30).opacity(0.30)
                : Color(red: 0.85, green: 0.60, blue: 0.20).opacity(0.25)
        } else {
            return scheme == .dark
                ? gold.opacity(0.25)
                : gold.opacity(0.20)
        }
    }

    // MARK: - 字体设计支持
    static var titleDesign: Font.Design {
        isXuanqing ? .serif : .default
    }

    static var bodyDesign: Font.Design { .default }
}
