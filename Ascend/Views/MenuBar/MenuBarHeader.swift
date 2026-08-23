import AppKit
import SwiftUI

struct MenuBarHeader: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    private var todayXP: Int {
        appState.todayXPGains.reduce(0) { $0 + $1.xp }
    }

    private var collectionStatusText: String {
        if appState.isScanningSources {
            return "巡察中"
        } else if appState.isCollecting && appState.isCollectionSchedulerRunning {
            return "采集中"
        } else {
            return "已暂停"
        }
    }

    private var collectionStatusColor: Color {
        if appState.isScanningSources {
            return AscendTheme.gold
        } else if appState.isCollecting && appState.isCollectionSchedulerRunning {
            return AscendTheme.jade
        } else {
            return AscendTheme.slate
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // 第一行：标题、道行与高频操作
            HStack(alignment: .firstTextBaseline) {
                Text("知境录")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)

                Spacer()

                Text("Lv.\(appState.learnerLevel)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AscendTheme.gold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AscendTheme.gold.opacity(0.12))
                    .clipShape(Capsule())
                    .help("道行等级 Lv.\(appState.learnerLevel) · 总知验 \(appState.totalXP.formatted()) XP")

                Button(action: { appState.isCollecting.toggle() }) {
                    Image(systemName: appState.isCollecting ? "pause.fill" : "play.fill")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(appState.isCollecting ? AscendTheme.jade : .secondary)
                .help(appState.isCollecting ? "暂停自动采集" : "开启自动采集")

                Button(action: openMainWindow) {
                    Image(systemName: "macwindow")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("打开知境录主窗口")
            }

            // 第二行：今日收益与采集状态
            HStack(alignment: .center) {
                if todayXP > 0 {
                    HStack(spacing: 3) {
                        Text("今日")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("+\(todayXP) XP")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AscendTheme.gold)
                    }
                    .help("今日累计知验收益 +\(todayXP) XP")
                } else {
                    Text("今日尚未修习")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(collectionStatusColor)
                        .frame(width: 6, height: 6)
                        .shadow(
                            color: appState.isCollecting && appState.isCollectionSchedulerRunning
                                ? collectionStatusColor.opacity(0.4)
                                : .clear,
                            radius: 2
                        )
                    Text(collectionStatusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func openMainWindow() {
        openWindow(id: "main")
        dismiss()
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
