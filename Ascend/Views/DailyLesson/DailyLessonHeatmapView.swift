import SwiftUI

/// 功行热力图：GitHub 风格 26 周格子。
/// 青玉深浅 = 当日日课完成数（自报承诺）；暖金描边 = 当日存在真实学习采集活动。二者不混算。
struct DailyLessonHeatmapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var heatmap: DailyLessonHeatmapData = .empty
    @State private var hoveredCellID: Date?

    private let weekCount = 26
    private let cellSize: CGFloat = 13
    private let cellSpacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            ScrollView(.horizontal, showsIndicators: false) {
                grid
            }

            legend
        }
        .onAppear(perform: reloadHeatmap)
        .onChange(of: appState.dailyLessonDay) { _, _ in
            reloadHeatmap()
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: heatmap)
    }

    // MARK: 数据

    private func reloadHeatmap() {
        heatmap = appState.dailyLessonHeatmap(weekCount: weekCount)
    }

    private var longestStreak: Int {
        appState.activeHabits
            .map { appState.longestHabitStreak(for: $0) }
            .max() ?? 0
    }

    // MARK: 头部

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AscendTheme.isXuanqing ? "功行热力" : "完成热力图")
                    .font(.system(.title3, design: AscendTheme.titleDesign))
                    .bold()
                Text("近 \(weekCount) 周 · 共完成 \(heatmap.totalCompletions) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 14) {
                summary(value: "\(heatmap.todayCompletions)", label: "今日")
                summary(value: "\(longestStreak)", label: "最长连续")
            }
        }
    }

    private func summary(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AscendTheme.jade)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 网格

    private var grid: some View {
        HStack(alignment: .top, spacing: 5) {
            VStack(spacing: cellSpacing) {
                ForEach(weekdaySymbols, id: \.offset) { item in
                    Text(item.symbol)
                        .font(.system(size: 9))
                        .foregroundStyle(item.visible ? Color.secondary : Color.clear)
                        .frame(width: 12, height: cellSize, alignment: .center)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                monthLabels
                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(Array(heatmap.columns.enumerated()), id: \.offset) { columnIndex, column in
                        columnView(column, columnIndex: columnIndex)
                    }
                }
            }
        }
        .padding(2)
    }

    /// 行序：周一 → 周日；仅标注一、三、五、日。
    private var weekdaySymbols: [(offset: Int, symbol: String, visible: Bool)] {
        [
            (0, "一", true), (1, "", false), (2, "三", true), (3, "", false),
            (4, "五", true), (5, "", false), (6, "日", true)
        ]
    }

    private var monthLabels: some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(Array(heatmap.columns.enumerated()), id: \.offset) { index, column in
                let label = monthLabel(column: column, previous: index > 0 ? heatmap.columns[index - 1] : nil)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize, alignment: .leading)
            }
        }
    }

    private func monthLabel(column: [DailyLessonHeatmapCell], previous: [DailyLessonHeatmapCell]?) -> String {
        guard let first = column.first else { return "" }
        let month = Calendar.current.component(.month, from: first.day)
        if let previous, let previousFirst = previous.first {
            return Calendar.current.component(.month, from: previousFirst.day) == month ? "" : "\(month)月"
        }
        return "\(month)月"
    }

    private func columnView(_ column: [DailyLessonHeatmapCell], columnIndex: Int) -> some View {
        VStack(spacing: cellSpacing) {
            ForEach(column) { cell in
                cellView(cell)
            }
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9)))
    }

    @ViewBuilder
    private func cellView(_ cell: DailyLessonHeatmapCell) -> some View {
        let isHovered = hoveredCellID == cell.day
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(fill(for: cell))
            if cell.hasLearningActivity {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(AscendTheme.gold.opacity(colorScheme == .dark ? 0.75 : 0.6), lineWidth: 1)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .opacity(cell.isFuture ? 0.12 : 1)
        .scaleEffect(isHovered ? 1.3 : 1)
        .onHover { hovered in
            guard !cell.isFuture else { return }
            hoveredCellID = hovered ? cell.day : (hoveredCellID == cell.day ? nil : hoveredCellID)
        }
        .overlay(alignment: .bottom) {
            if isHovered {
                tooltip(cell)
                    .offset(y: 22)
                    .zIndex(10)
            }
        }
        .accessibilityLabel(accessibilityText(for: cell))
    }

    private func fill(for cell: DailyLessonHeatmapCell) -> Color {
        switch cell.completionCount {
        case 0: AscendTheme.subtleSurface(for: colorScheme)
        case 1: AscendTheme.jade.opacity(0.28)
        case 2: AscendTheme.jade.opacity(0.48)
        case 3: AscendTheme.jade.opacity(0.68)
        default: AscendTheme.jade.opacity(0.88)
        }
    }

    private func tooltip(_ cell: DailyLessonHeatmapCell) -> some View {
        Text(tooltipText(for: cell))
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .ascendGlass(
                in: RoundedRectangle(cornerRadius: 5, style: .continuous),
                tint: AscendTheme.inkJade.opacity(colorScheme == .dark ? 0.55 : 0.25)
            )
            .foregroundStyle(.primary)
    }

    private func tooltipText(for cell: DailyLessonHeatmapCell) -> String {
        var text = "\(cell.day.formatted(date: .abbreviated, time: .omitted)) · 完成 \(cell.completionCount) 项"
        if cell.hasLearningActivity {
            text += " · 有真实学习"
        }
        return text
    }

    private func accessibilityText(for cell: DailyLessonHeatmapCell) -> String {
        if cell.isFuture { return "未来日期" }
        var text = "\(cell.day.formatted(date: .abbreviated, time: .omitted))，完成 \(cell.completionCount) 项"
        if cell.hasLearningActivity { text += "，当日有真实学习活动" }
        return text
    }

    // MARK: 图例

    private var legend: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("少")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach([0, 1, 2, 3, 4], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(fill(for: DailyLessonHeatmapCell(
                            day: .distantPast,
                            completionCount: level,
                            hasLearningActivity: false,
                            isFuture: false
                        )))
                        .frame(width: 10, height: 10)
                }
                Text("多")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(AscendTheme.subtleSurface(for: colorScheme))
                    .frame(width: 10, height: 10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 2.5)
                            .strokeBorder(AscendTheme.gold.opacity(0.6), lineWidth: 1)
                    }
                Text("有真实学习活动")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
