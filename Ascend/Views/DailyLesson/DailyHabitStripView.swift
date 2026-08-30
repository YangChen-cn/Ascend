import SwiftUI

/// 习惯打卡条：玉环 + 名称 + 暖金连续天数；点击即打卡/撤销。
struct DailyHabitStripView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onEdit: (DailyTask) -> Void = { _ in }

    var body: some View {
        let habits = appState.todayHabits()
        if !habits.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(AscendTheme.isXuanqing ? "日课修习" : "习惯打卡")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowLayoutishRow(spacing: 8) {
                    ForEach(habits) { habit in
                        HabitChip(habit: habit, onEdit: onEdit)
                    }
                }
            }
        }
    }
}

private struct HabitChip: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let habit: DailyTask
    var onEdit: (DailyTask) -> Void

    @State private var isHovered = false
    @State private var ringPulse = false

    private var isCompleted: Bool {
        appState.isHabitCompletedToday(habit)
    }

    private var streak: Int {
        appState.habitStreak(for: habit)
    }

    var body: some View {
        Button(action: checkIn) {
            HStack(spacing: 8) {
                ring
                VStack(alignment: .leading, spacing: 1) {
                    Text(habit.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    if streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8))
                            Text("\(streak) 天")
                        }
                        .font(.caption2)
                        .foregroundStyle(AscendTheme.gold)
                    }
                }

                if isHovered {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .frame(width: 16, height: 20)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .ascendGlass(
                in: Capsule(),
                tint: isCompleted
                    ? AscendTheme.jade.opacity(colorScheme == .dark ? 0.14 : 0.08)
                    : AscendTheme.subtleSurface(for: colorScheme)
            )
            .overlay {
                Capsule().strokeBorder(chipStroke, lineWidth: 0.9)
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1)
        .onHover { hovered in
            guard !reduceMotion else { isHovered = hovered; return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isHovered = hovered }
        }
        .contextMenu {
            Button("编辑习惯") { onEdit(habit) }
            Button("停用习惯", role: .destructive) {
                appState.archiveDailyTask(habit)
            }
        }
        .accessibilityLabel("\(habit.title)，\(isCompleted ? "今日已完成" : "今日未完成")，连续 \(streak) 天")
        .help(isCompleted ? "点击撤销今日打卡" : "点击打卡")
    }

    private var ring: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isCompleted ? AscendTheme.jade : AscendTheme.border(for: colorScheme),
                    lineWidth: 1.6
                )
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AscendTheme.jade)
                    .scaleEffect(ringPulse ? 1 : 0.4)
            }
        }
        .frame(width: 22, height: 22)
    }

    private var chipStroke: Color {
        isCompleted ? AscendTheme.jade.opacity(0.45) : AscendTheme.border(for: colorScheme)
    }

    private func checkIn() {
        appState.toggleHabit(habit)
        guard !reduceMotion, isCompleted else { return }
        ringPulse = false
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            ringPulse = true
        }
    }
}

/// 简化版流式排布：单行放不下时换行，避免横向滚动。
private struct FlowLayoutishRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: height + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
