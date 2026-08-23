import SwiftUI

enum AscendTheme {
    private static var visualTheme: VisualTheme {
        VisualTheme(rawValue: UserDefaults.standard.string(forKey: "visualTheme") ?? "") ?? .xuanqing
    }

    // MARK: - 核心灵韵色彩
    /// 碧落灵翠（灵根、掌握度、生机）
    static var jade: Color {
        Color(red: 0.08, green: 0.72, blue: 0.55)
    }

    /// 深邃墨翠
    static var deepJade: Color {
        Color(red: 0.03, green: 0.38, blue: 0.32)
    }

    /// 九天流金（知验、道纹、大境界）
    static var gold: Color {
        Color(red: 0.95, green: 0.72, blue: 0.22)
    }

    /// 幽蓝云水（灵脉、星轨、清虚之气）
    static var cobalt: Color {
        Color(red: 0.22, green: 0.65, blue: 0.88)
    }

    /// 朱砂赤曜（修炼试炼、挑战突破）
    static var amber: Color {
        Color(red: 0.92, green: 0.32, blue: 0.24)
    }

    /// 月魄霜华（微光高亮）
    static var frost: Color {
        Color(red: 0.92, green: 0.96, blue: 0.98)
    }

    static let slate = Color(red: 0.45, green: 0.52, blue: 0.58)

    // MARK: - 仙家流光渐变
    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.86, blue: 0.45), Color(red: 0.88, green: 0.58, blue: 0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var jadeGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.25, green: 0.88, blue: 0.68), Color(red: 0.05, green: 0.58, blue: 0.42)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var astralGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.38, green: 0.78, blue: 0.98), Color(red: 0.10, green: 0.45, blue: 0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cinnabarGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.98, green: 0.42, blue: 0.32), Color(red: 0.82, green: 0.18, blue: 0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - 背景与材质
    static func background(for scheme: ColorScheme) -> Color {
        if scheme == .dark {
            // 太虚玄渊：深邃墨玉黑中透出丝缕青气
            return Color(red: 0.032, green: 0.050, blue: 0.058)
        } else {
            // 素绢云宣：温润羊脂暖玉白
            return Color(red: 0.978, green: 0.965, blue: 0.925)
        }
    }

    static func surface(for scheme: ColorScheme) -> Color {
        if scheme == .dark {
            // 高透墨玉毛玻璃
            return Color(red: 0.065, green: 0.095, blue: 0.110)
        } else {
            // 羊脂白玉微透
            return Color(red: 0.995, green: 0.988, blue: 0.965)
        }
    }

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.20, green: 0.45, blue: 0.45).opacity(0.35)
            : Color(red: 0.70, green: 0.65, blue: 0.55).opacity(0.30)
    }

    static func goldenBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.95, green: 0.75, blue: 0.30).opacity(0.30)
            : Color(red: 0.85, green: 0.60, blue: 0.20).opacity(0.25)
    }
}
