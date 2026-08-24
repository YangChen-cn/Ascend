import SwiftUI

struct MenuBarHeader: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var isHoveredOpen = false

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
            return MenuBarPalette.gold(colorScheme)
        } else if appState.isCollecting && appState.isCollectionSchedulerRunning {
            return MenuBarPalette.jade(colorScheme)
        } else {
            return MenuBarPalette.secondaryInk(colorScheme)
        }
    }

    private var levelTitle: String {
        "\(chineseNumber(appState.learnerLevel))境"
    }

    var body: some View {
        VStack(spacing: 8) {
            // 第一行：标题 + 等级
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Text("知境录")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(MenuBarPalette.ink(colorScheme))

                    Text(levelTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MenuBarPalette.gold(colorScheme))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(MenuBarPalette.gold(colorScheme).opacity(0.08))
                        .clipShape(.rect(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(MenuBarPalette.gold(colorScheme).opacity(0.30), lineWidth: 0.7)
                        }
                        .help("道行第 \(appState.learnerLevel) 境 · 总知验 \(appState.totalXP.formatted()) XP")
                }

                Spacer()
            }

            // 第二行：今日收益 + 打开主窗口按钮 + 采集状态（并排）
            HStack(alignment: .center, spacing: 8) {
                if todayXP > 0 {
                    HStack(spacing: 4) {
                        Text("今日所得")
                            .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                        Text("+\(todayXP) XP")
                            .fontWeight(.semibold)
                            .foregroundStyle(MenuBarPalette.gold(colorScheme))
                    }
                    .font(.system(size: 11))
                } else {
                    Text("今日尚未修习")
                        .font(.system(size: 11))
                        .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                }

                Spacer(minLength: 4)

                // 打开知境录按钮（与采集中并排）
                Button(action: openMainWindow) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10, weight: .semibold))
                        Text("打开知境录")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(MenuBarPalette.ink(colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isHoveredOpen ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(isHoveredOpen ? 0.18 : 0.08), lineWidth: 0.7)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .onHover { isHoveredOpen = $0 }
                .help("打开知境录主窗口 (⌘O)")

                // 采集状态
                Button(action: { appState.isCollecting.toggle() }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(collectionStatusColor)
                            .frame(width: 6, height: 6)
                        Text(collectionStatusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                    }
                }
                .buttonStyle(.plain)
                .help(appState.isCollecting ? "自动采集中（点击暂停）" : "自动采集已暂停（点击开启）")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(alignment: .trailing) {
            MenuBarMountainShape()
                .stroke(MenuBarPalette.ink(colorScheme), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .frame(width: 165, height: 64)
                .opacity(colorScheme == .dark ? 0.055 : 0.04)
                .padding(.trailing, 8)
        }
    }

    private func chineseNumber(_ value: Int) -> String {
        let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        let safeValue = max(1, value)
        guard safeValue < 100 else { return "\(safeValue)" }
        if safeValue < 10 { return digits[safeValue] }
        let tens = safeValue / 10
        let ones = safeValue % 10
        let prefix = tens == 1 ? "十" : digits[tens] + "十"
        return ones == 0 ? prefix : prefix + digits[ones]
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
