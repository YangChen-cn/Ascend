import AppKit
import SwiftUI

/// 专注小窗的窗口桥接：置顶层级、背景拖拽与隐藏系统红绿灯。
/// 照 MenuBarWindowPositioner 的 NSViewRepresentable 模式。
struct FocusWindowLevelSetter: NSViewRepresentable {
    let floatsOnTop: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        configure(view.window)
    }

    private static func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func configure(_ window: NSWindow?) {
        Self.configure(window)
        window?.level = floatsOnTop ? .floating : .normal
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
