import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isReviewSheetPresented = false

    private var isTrulyEmpty: Bool {
        let hasSources = !appState.sources.isEmpty
        let hasNodes = !appState.knowledgeNodes.isEmpty
        let hasActivity = appState.todayActivityCount > 0 || appState.pendingActivityCount > 0
        let hasXP = appState.todayXPGains.reduce(0) { $0 + $1.xp } > 0
        return !hasSources && !hasNodes && !hasActivity && !hasXP
    }

    private var hasActiveDomain: Bool {
        appState.domainProgress.contains { $0.xp > 0 || $0.currentScore > 0 }
    }

    private var hasAttentionItems: Bool {
        if appState.reviewPlans.contains(where: { $0.status == "due" }) { return true }
        if appState.forgettingProjections.contains(where: { $0.retention < 60 }) { return true }
        if appState.taxonomySuggestions.contains(where: { $0.status == "pending" }) { return true }
        if appState.challenges.contains(where: { challenge in
            guard challenge.status == "in_progress",
                  let automation = appState.challengeAutomationStates.first(where: { $0.challengeID == challenge.id }) else {
                return false
            }
            let target = max(automation.requirement.requiredEvidenceCount, challenge.knowledgeNodeIDs.count)
            let matched = Set(automation.matchedEvidenceIDs).count
            return target > 0 && matched > 0 && matched < target && Double(matched) / Double(target) >= 0.5
        }) { return true }
        if appState.sources.contains(where: { $0.isEnabled && $0.lastSyncError != nil }) { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            MenuBarHeader()

            Divider()
                .overlay(MenuBarPalette.divider(colorScheme))

            if isTrulyEmpty {
                MenuBarEmptyStateView()
            } else {
                MenuBarDashboardViewport(
                    hasAttentionItems: hasAttentionItems,
                    hasActiveDomain: hasActiveDomain,
                    isReviewSheetPresented: $isReviewSheetPresented
                )
            }

            Divider()
                .overlay(MenuBarPalette.divider(colorScheme))

            MenuBarQuickActions()
        }
        .frame(width: 384)
        .background(
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                Rectangle()
                    .fill(MenuBarPalette.paperWash(colorScheme))
                LinearGradient(
                    colors: [
                        MenuBarPalette.gold(colorScheme).opacity(colorScheme == .dark ? 0.025 : 0.018),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                MenuBarWindowPositioner()
            }
        )
        .sheet(isPresented: $isReviewSheetPresented) {
            TaxonomyReviewSheet()
        }
    }

}

// MARK: - 菜单栏弹窗智能居中定位器

@MainActor
private struct MenuBarWindowPositioner: NSViewRepresentable {
    func makeNSView(context: Context) -> PositionerView {
        PositionerView()
    }

    func updateNSView(_ nsView: PositionerView, context: Context) {}

    @MainActor
    final class PositionerView: NSView {
        private var isPositionedForPresentation = false
        private var lastKnownAnchorX: CGFloat?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            isPositionedForPresentation = false
            guard let window else { return }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey(_:)),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey(_:)),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
            scheduleCenter(window: window)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func windowDidBecomeKey(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            scheduleCenter(window: window)
        }

        @objc private func windowDidResignKey(_ notification: Notification) {
            isPositionedForPresentation = false
        }

        private func scheduleCenter(window: NSWindow) {
            guard !isPositionedForPresentation else { return }
            let mouseLocation = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
                ?? window.screen
                ?? NSScreen.main
            guard let screen else { return }

            if let clickedAnchorX = MenuBarWindowPositioning.statusItemAnchorX(
                mouseLocation: mouseLocation,
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame
            ) {
                lastKnownAnchorX = clickedAnchorX
            }

            // MenuBarExtra 首次出现时系统通常将窗口左缘放在状态项附近。
            // 只有尚未捕获过真实点击位置时才使用这个一次性兜底值。
            let anchorX = lastKnownAnchorX ?? window.frame.minX + 14
            let newX = MenuBarWindowPositioning.centeredOriginX(
                anchorX: anchorX,
                windowWidth: window.frame.width,
                visibleFrame: screen.visibleFrame
            )

            // 必须在当前窗口生命周期回调内同步定位。若让出一个 MainActor
            // 调度周期，系统会先绘制默认位置，再移动到目标位置，形成闪烁。
            if abs(window.frame.minX - newX) > 1 {
                window.setFrameOrigin(CGPoint(x: newX, y: window.frame.minY))
            }
            isPositionedForPresentation = true
        }
    }
}
