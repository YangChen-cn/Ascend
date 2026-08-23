import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isReviewSheetPresented = false

    private var hasLeadingDomain: Bool {
        appState.domainProgress.first != nil && appState.totalXP > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部 Header (道行等级 / XP / 状态徽标)
            MenuBarHeader()

            Divider()

            // 2. 核心 3×2 快捷导航网格
            MenuBarNavigationGrid()

            Divider()

            // 3. 动态重点关注区域 (急需温故 / 待审真意 / 活跃挑战 / 今日精进)
            MenuBarAttentionSection(isReviewSheetPresented: $isReviewSheetPresented)

            // 4. 首席灵根与修行境界 (压缩版)
            if hasLeadingDomain {
                Divider()
                MenuBarRealmSummary()
            }

            Divider()

            // 5. 底部快捷操作与分析控制台
            MenuBarQuickActions()
        }
        .frame(width: 368)
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
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window = self.window else { return }

            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                self.centerWindowUnderStatusItem(window: window)
            }
        }

        private func centerWindowUnderStatusItem(window: NSWindow) {
            guard let screen = window.screen ?? NSScreen.main else { return }
            let mouseLocation = NSEvent.mouseLocation
            let windowWidth = window.frame.width

            var targetMidX: CGFloat = window.frame.origin.x + 14
            // 若鼠标在菜单栏区域（顶部 40pt 内），以鼠标触发点作为状态栏图标中点
            if mouseLocation.y >= screen.visibleFrame.maxY - 40 {
                targetMidX = mouseLocation.x
            }

            var newX = targetMidX - (windowWidth / 2)
            let minX = screen.visibleFrame.minX + 8
            let maxX = screen.visibleFrame.maxX - windowWidth - 8
            newX = min(max(newX, minX), maxX)

            var newOrigin = window.frame.origin
            newOrigin.x = newX
            window.setFrameOrigin(newOrigin)
        }
    }
}
