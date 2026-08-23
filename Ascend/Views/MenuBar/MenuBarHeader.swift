import SwiftUI

struct MenuBarHeader: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    private var todayXP: Int {
        appState.todayXPGains.reduce(0) { $0 + $1.xp }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 左侧：知境录标题与道行等级
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(AscendTheme.gold)

                Text("知境录")
                    .font(.system(.headline, design: .serif))
                    .bold()

                Text("Lv.\(appState.learnerLevel)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AscendTheme.gold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(AscendTheme.gold.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()

            // 中右侧：今日收益与总知验
            HStack(spacing: 8) {
                if todayXP > 0 {
                    HStack(spacing: 2) {
                        Text("+\(todayXP)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AscendTheme.gold)
                        Text("今日")
                            .font(.system(size: 9, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AscendTheme.gold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text("\(appState.totalXP.formatted()) XP")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                // 自动采集运行状态小点
                Button(action: { appState.isCollecting.toggle() }) {
                    Circle()
                        .fill(appState.isCollectionSchedulerRunning ? AscendTheme.jade : AscendTheme.slate)
                        .frame(width: 7, height: 7)
                        .shadow(color: appState.isCollectionSchedulerRunning ? AscendTheme.jade.opacity(0.6) : .clear, radius: 2)
                }
                .buttonStyle(.plain)
                .help(appState.isCollectionSchedulerRunning ? "自动采集中（点击暂停）" : "自动采集已暂停（点击开启）")

                // 待分析数量徽标（如有）
                if appState.pendingActivityCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 8))
                        Text("\(appState.pendingActivityCount)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(AscendTheme.amber)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(AscendTheme.amber.opacity(0.12))
                    .clipShape(Capsule())
                    .help("\(appState.pendingActivityCount) 条实据待悟道分析")
                }

                // 一键打开主窗口
                Button(action: openMainWindow) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("打开知境录主窗口")
            }
        }
        .padding(.horizontal, 14)
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
