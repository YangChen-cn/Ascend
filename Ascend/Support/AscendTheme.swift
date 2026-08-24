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
            ? Color(red: 0.10, green: 0.54, blue: 0.42)
            : Color(red: 0.10, green: 0.43, blue: 0.83)
    }

    static var deepJade: Color {
        isXuanqing
            ? Color(red: 0.05, green: 0.35, blue: 0.28)
            : Color(red: 0.05, green: 0.28, blue: 0.62)
    }

    static var gold: Color {
        isXuanqing
            ? Color(red: 0.80, green: 0.56, blue: 0.16)
            : Color(red: 0.92, green: 0.62, blue: 0.15)
    }

    static var cobalt: Color {
        isXuanqing
            ? jade
            : Color(red: 0.10, green: 0.43, blue: 0.83)
    }

    static var amber: Color {
        isXuanqing
            ? Color(red: 0.86, green: 0.36, blue: 0.20)
            : Color(red: 0.94, green: 0.42, blue: 0.12)
    }

    // 朱砂色：典雅纯正的朱红，用于书签、印记与重点标识
    static var cinnabar: Color {
        isXuanqing
            ? Color(red: 0.78, green: 0.22, blue: 0.18)
            : Color(red: 0.85, green: 0.24, blue: 0.20)
    }

    // 墨玉色：深沉内敛的墨绿玄色
    static var inkJade: Color {
        isXuanqing
            ? Color(red: 0.10, green: 0.18, blue: 0.16)
            : Color(red: 0.18, green: 0.21, blue: 0.26)
    }

    static var frost: Color {
        isXuanqing
            ? Color(red: 0.94, green: 0.96, blue: 0.97)
            : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    static let slate = Color(red: 0.45, green: 0.52, blue: 0.58)

    // MARK: - 渐变体系
    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: isXuanqing
                ? [Color(red: 0.92, green: 0.72, blue: 0.28), Color(red: 0.78, green: 0.50, blue: 0.12)]
                : [Color(red: 0.98, green: 0.75, blue: 0.25), Color(red: 0.92, green: 0.55, blue: 0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var jadeGradient: LinearGradient {
        LinearGradient(
            colors: isXuanqing
                ? [Color(red: 0.14, green: 0.68, blue: 0.52), Color(red: 0.06, green: 0.45, blue: 0.34)]
                : [Color(red: 0.28, green: 0.60, blue: 0.96), Color(red: 0.08, green: 0.36, blue: 0.76)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var astralGradient: LinearGradient {
        LinearGradient(
            colors: isXuanqing
                ? [Color(red: 0.20, green: 0.65, blue: 0.60), Color(red: 0.08, green: 0.40, blue: 0.45)]
                : [Color(red: 0.25, green: 0.58, blue: 0.95), Color(red: 0.10, green: 0.35, blue: 0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cinnabarGradient: LinearGradient {
        LinearGradient(
            colors: isXuanqing
                ? [Color(red: 0.88, green: 0.32, blue: 0.26), Color(red: 0.72, green: 0.16, blue: 0.12)]
                : [Color(red: 0.95, green: 0.35, blue: 0.25), Color(red: 0.85, green: 0.20, blue: 0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - 背景与表面材质
    static func background(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.045, green: 0.062, blue: 0.068) // 太虚玄渊墨潭
                : Color(red: 0.964, green: 0.962, blue: 0.956) // 澄心堂素宣米白
        } else {
            return scheme == .dark
                ? Color(red: 0.065, green: 0.080, blue: 0.110) // 现代深空灰
                : Color(red: 0.975, green: 0.980, blue: 0.988) // 纯净淡灰底
        }
    }

    static func surface(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.082, green: 0.112, blue: 0.120) // 墨玉毛玻璃
                : Color.white // 纯净温润白玉卡片
        } else {
            return scheme == .dark
                ? Color(red: 0.110, green: 0.135, blue: 0.175) // 现代深色卡片
                : Color.white // 现代纯白卡片
        }
    }

    static func elevatedSurface(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.095, green: 0.130, blue: 0.138)
                : Color.white
        }
        return scheme == .dark
            ? Color(red: 0.13, green: 0.15, blue: 0.19)
            : Color.white
    }

    static func subtleSurface(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color.white.opacity(0.04)
                : inkJade.opacity(0.03)
        }
        return Color.primary.opacity(scheme == .dark ? 0.055 : 0.035)
    }

    static func separator(for scheme: ColorScheme) -> Color {
        isXuanqing
            ? (scheme == .dark ? Color.white.opacity(0.10) : Color(red: 0.78, green: 0.74, blue: 0.68).opacity(0.35))
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
                ? Color(red: 0.25, green: 0.50, blue: 0.45).opacity(0.35)
                : Color(red: 0.80, green: 0.76, blue: 0.68).opacity(0.50)
        } else {
            return scheme == .dark
                ? Color.white.opacity(0.10)
                : Color(red: 0.88, green: 0.90, blue: 0.93)
        }
    }

    static func goldenBorder(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.92, green: 0.72, blue: 0.28).opacity(0.35)
                : Color(red: 0.80, green: 0.56, blue: 0.16).opacity(0.30)
        } else {
            return scheme == .dark
                ? gold.opacity(0.25)
                : gold.opacity(0.20)
        }
    }

    // MARK: - 古风装裱与印泥美学支持
    static var sealRed: Color {
        Color(red: 0.85, green: 0.22, blue: 0.18)
    }

    static var inkGold: Color {
        Color(red: 0.90, green: 0.68, blue: 0.24)
    }

    static func xuanPaperWash(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.05, green: 0.08, blue: 0.09).opacity(0.65)
                : Color(red: 0.99, green: 0.975, blue: 0.945).opacity(0.80)
        } else {
            return scheme == .dark
                ? Color.white.opacity(0.04)
                : Color.black.opacity(0.02)
        }
    }

    static func classicalInnerBorder(for scheme: ColorScheme) -> Color {
        if isXuanqing {
            return scheme == .dark
                ? Color(red: 0.95, green: 0.75, blue: 0.30).opacity(0.12)
                : Color(red: 0.65, green: 0.55, blue: 0.40).opacity(0.15)
        } else {
            return Color.clear
        }
    }

    // MARK: - 字体设计支持
    static var titleDesign: Font.Design {
        isXuanqing ? .serif : .default
    }

    static var bodyDesign: Font.Design { .default }
}
