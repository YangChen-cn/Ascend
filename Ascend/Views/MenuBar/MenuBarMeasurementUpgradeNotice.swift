import AppKit
import SwiftUI

struct MenuBarMeasurementUpgradeNotice: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("需要升级测量体系", systemImage: "exclamationmark.shield")
                .font(.headline)

            Text("旧评分仍被保留，尚未转换为可验证掌握估计。请在主窗口确认清理与重建。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("打开升级确认", systemImage: "macwindow", action: openUpgrade)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func openUpgrade() {
        openWindow(id: "main")
        dismiss()
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
