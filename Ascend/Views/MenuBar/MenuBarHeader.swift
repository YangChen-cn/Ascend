import SwiftUI

struct MenuBarHeader: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

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
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("知境录")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(MenuBarPalette.ink(colorScheme))

                Spacer()

                Text(levelTitle)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(MenuBarPalette.gold(colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(MenuBarPalette.gold(colorScheme).opacity(0.07))
                    .clipShape(.rect(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(MenuBarPalette.gold(colorScheme).opacity(0.30), lineWidth: 0.7)
                    }
                    .help("道行第 \(appState.learnerLevel) 境 · 总知验 \(appState.totalXP.formatted()) XP")
            }

            HStack(alignment: .center) {
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

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(collectionStatusColor)
                        .frame(width: 6, height: 6)
                    Text(collectionStatusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                }
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
}
