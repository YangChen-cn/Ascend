import AppKit
import SwiftUI

/// 精准直达指定设置 Tab 的按钮组件
/// 在 macOS SwiftUI 中结合 @Environment(\.openSettings) 与 AppState 双向绑定，确保 100% 唤起并精准跳转
struct TargetedSettingsButton<LabelContent: View>: View {
    let section: SettingsSection
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings
    @ViewBuilder let label: () -> LabelContent

    var body: some View {
        Button(action: triggerOpenSettings) {
            label()
        }
    }

    private func triggerOpenSettings() {
        appState.selectedSettingsSection = section

        // 1. 首选 SwiftUI 官方环境变量
        openSettings()
        NSApp.activate(ignoringOtherApps: true)

        // 2. 兜底方案：触发应用主菜单 Preferences / Settings 菜单项
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let menu = NSApp.mainMenu {
                for item in menu.items {
                    if let submenu = item.submenu {
                        for subItem in submenu.items {
                            if subItem.keyEquivalent == "," && subItem.keyEquivalentModifierMask.contains(.command) {
                                if let action = subItem.action {
                                    NSApp.sendAction(action, to: subItem.target, from: nil)
                                    return
                                }
                            }
                        }
                    }
                }
            }
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil as Any?, from: nil as Any?)
        }
    }
}
