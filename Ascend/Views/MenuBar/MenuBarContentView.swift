import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isReviewSheetPresented = false

    private var hasActiveDomain: Bool {
        appState.domainProgress.contains { $0.xp > 0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            MenuBarHeader()

            Divider()

            MenuBarNavigationGrid()

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    MenuBarTodaySummary()

                    Divider()

                    MenuBarAttentionSection(isReviewSheetPresented: $isReviewSheetPresented)

                    if hasActiveDomain {
                        Divider()
                        MenuBarRealmSummary()
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 310)

            Divider()

            MenuBarSourceHealth()

            Divider()

            MenuBarQuickActions()
        }
        .frame(width: 396)
        .frame(maxHeight: 610)
        .background(
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                LinearGradient(
                    colors: [
                        AscendTheme.gold.opacity(colorScheme == .dark ? 0.04 : 0.02),
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
