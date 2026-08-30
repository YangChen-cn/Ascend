import SwiftUI

/// Liquid Glass（macOS 26+）与 Material 的双轨封装。
/// 仅用于交互与强调元素（快速输入框、打卡控件、专注窗面、浮层提示）；
/// 页面整体仍遵循既有玄墨 / 清境卡片体系，避免玻璃质感铺满。
private struct AscendGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    var tint: Color?
    var isInteractive: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else if let tint {
            content
                .background(tint, in: shape)
                .overlay {
                    shape.strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
                }
        } else {
            content
                .background(fallbackMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
                }
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        var base = Glass.regular
        if let tint {
            base = base.tint(tint)
        }
        if isInteractive {
            base = base.interactive()
        }
        return base
    }

    private var fallbackMaterial: Material {
        isInteractive ? .regularMaterial : .ultraThinMaterial
    }
}

extension View {
    /// 玻璃质感容器：macOS 26 使用 Liquid Glass，低版本自动回落 Material 并保留细描边。
    func ascendGlass<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(AscendGlassModifier(shape: shape, tint: tint, isInteractive: interactive))
    }
}
