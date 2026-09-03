import AppKit

/// SwiftUI 与 macOS 通用剪贴板之间的最小命令式边界。
@MainActor
enum SystemClipboard {
    @discardableResult
    static func copy(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
