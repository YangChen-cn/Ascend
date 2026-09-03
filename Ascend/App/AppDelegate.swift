import AppKit
import Foundation
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static let reopenMainWindowNotification = Notification.Name("com.yang.Ascend.reopen-main-window")

    var startAutomation: (@MainActor @Sendable () async -> Void)? {
        didSet { startAutomationIfReady() }
    }
    var handleNotificationNavigation: (@MainActor @Sendable (NotificationNavigationDestination) -> Void)?
    private var didFinishLaunching = false
    private var didStartAutomation = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        UNUserNotificationCenter.current().delegate = self
        didFinishLaunching = true
        startAutomationIfReady()
        AppLogger.app.info("知境录 launched")
    }

    private func startAutomationIfReady() {
        guard didFinishLaunching,
              !didStartAutomation,
              let startAutomation else { return }
        didStartAutomation = true
        Task { @MainActor in
            await startAutomation()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        if let mainWindow = sender.windows.first(where: { $0.title == "知境录" && $0.canBecomeMain }) {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            // SwiftUI 的 Window 场景可能在关闭后销毁 NSWindow；让常驻的菜单栏路由器
            // 通过 openWindow(id:) 重新创建，而不是只尝试唤醒一个不存在的窗口。
            NotificationCenter.default.post(name: Self.reopenMainWindowNotification, object: nil)
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }

    // 允许应用在前台或后台时均能正常展示系统通知横幅
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let destination = NotificationNavigationDestination(
            userInfo: response.notification.request.content.userInfo
        ), let handleNotificationNavigation {
            Task { @MainActor in
                handleNotificationNavigation(destination)
            }
        }
        completionHandler()
    }
}
