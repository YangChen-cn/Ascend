import SwiftUI

/// 菜单栏日课区块：今日习惯打卡、待办速览、快速新增与入定入口。
struct MenuBarDailyLessonSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var quickAddText = ""
    @FocusState private var isQuickAddFocused: Bool
    @State private var hoveredItemID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow

            habitRow
            todoRows
            quickAddField
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: 头部

    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 9))
                    .foregroundStyle(MenuBarPalette.jade(colorScheme))

                Text("日课")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(MenuBarPalette.ink(colorScheme))
            }

            Spacer()

            if let remaining = appState.focusRemainingSeconds {
                focusPill(remaining: remaining)
            } else {
                Button(action: openFocusWindow) {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("入定")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(MenuBarPalette.gold(colorScheme))
                }
                .buttonStyle(MenuBarPressButtonStyle())
                .help("打开专注小窗")
            }
        }
        .padding(.horizontal, 2)
    }

    private func focusPill(remaining: Int) -> some View {
        Button(action: openFocusWindow) {
            HStack(spacing: 4) {
                Circle()
                    .fill(MenuBarPalette.gold(colorScheme))
                    .frame(width: 5, height: 5)
                Text(FocusGlanceCardView.format(seconds: remaining))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(MenuBarPalette.gold(colorScheme).opacity(0.12))
            )
        }
        .buttonStyle(MenuBarPressButtonStyle())
        .help("专注进行中，点击查看")
    }

    // MARK: 习惯

    @ViewBuilder
    private var habitRow: some View {
        let habits = appState.todayHabits()
        if !habits.isEmpty {
            HStack(spacing: 6) {
                ForEach(habits.prefix(5)) { habit in
                    MenuBarHabitCircle(habit: habit)
                }
                Spacer()
                let totals = appState.todayDailyTaskTotals()
                if totals.total > 0 {
                    Text("\(totals.done)/\(totals.total)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: 待办

    @ViewBuilder
    private var todoRows: some View {
        let (open, completed) = appState.todayTodoGroups()
        let rows = Array(open.prefix(2))
        if !rows.isEmpty || !completed.isEmpty {
            VStack(spacing: 0) {
                ForEach(rows) { task in
                    MenuBarTodoRow(
                        task: task,
                        isHovered: hoveredItemID == task.id.uuidString,
                        onHover: { hovering in
                            hoveredItemID = hovering ? task.id.uuidString : nil
                        },
                        onToggle: {
                            appState.toggleTodo(task)
                        },
                        onOpen: { openTodayPage() }
                    )
                }
                if rows.isEmpty, let done = completed.first {
                    MenuBarTodoRow(
                        task: done,
                        isHovered: hoveredItemID == done.id.uuidString,
                        onHover: { hovering in
                            hoveredItemID = hovering ? done.id.uuidString : nil
                        },
                        onToggle: {
                            appState.toggleTodo(done)
                        },
                        onOpen: { openTodayPage() }
                    )
                }
            }
        }
    }

    // MARK: 快速新增

    private var quickAddField: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle")
                .font(.system(size: 10))
                .foregroundStyle(MenuBarPalette.jade(colorScheme))

            TextField("记一件要做的事…", text: $quickAddText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isQuickAddFocused)
                .onSubmit(addQuickTodo)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(MenuBarPalette.paperWash(colorScheme).opacity(0.5))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(MenuBarPalette.divider(colorScheme), lineWidth: 0.6)
        }
        .padding(.top, 2)
    }

    // MARK: 行为

    private func addQuickTodo() {
        let title = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        appState.addDailyTask(title: title)
        quickAddText = ""
        isQuickAddFocused = false
    }

    private func openFocusWindow() {
        openWindow(id: "focus")
        dismiss()
    }

    private func openTodayPage() {
        appState.selectedSection = .today
        openWindow(id: "main")
        dismiss()
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - 习惯打卡圆

private struct MenuBarHabitCircle: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    let habit: DailyTask

    private var isCompleted: Bool {
        appState.isHabitCompletedToday(habit)
    }

    private var streak: Int {
        appState.habitStreak(for: habit)
    }

    var body: some View {
        Button {
            appState.toggleHabit(habit)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isCompleted ? MenuBarPalette.jade(colorScheme) : MenuBarPalette.divider(colorScheme),
                            lineWidth: 1.4
                        )
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(MenuBarPalette.jade(colorScheme))
                    }
                }
                .frame(width: 18, height: 18)

                Text(habitTitle)
                    .font(.system(size: 9))
                    .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                    .lineLimit(1)

                if streak > 0 {
                    Text("\(streak)天")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(MenuBarPalette.gold(colorScheme))
                } else {
                    Text(" ")
                        .font(.system(size: 8))
                }
            }
            .frame(width: 52)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isCompleted ? MenuBarPalette.jade(colorScheme).opacity(0.08) : .clear)
            )
            .contentShape(.rect)
        }
        .buttonStyle(MenuBarPressButtonStyle())
        .help("\(habit.title)：\(isCompleted ? "今日已完成" : "点击打卡")")
        .accessibilityLabel("\(habit.title)，\(isCompleted ? "今日已完成" : "今日未完成")，连续 \(streak) 天")
    }

    private var habitTitle: String {
        String(habit.title.prefix(4))
    }
}

// MARK: - 待办行

private struct MenuBarTodoRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let task: DailyTask
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onToggle: () -> Void
    let onOpen: () -> Void

    private var isCompleted: Bool { task.completedAt != nil }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isCompleted ? MenuBarPalette.jade(colorScheme) : MenuBarPalette.divider(colorScheme),
                            lineWidth: 1.4
                        )
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(MenuBarPalette.jade(colorScheme))
                    }
                }
                .frame(width: 16, height: 16)
                .contentShape(.circle)
            }
            .buttonStyle(MenuBarPressButtonStyle())
            .help(isCompleted ? "撤销完成" : "标记完成")

            Button(action: onOpen) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 12))
                        .strikethrough(isCompleted, color: .secondary)
                        .foregroundStyle(
                            isCompleted ? MenuBarPalette.secondaryInk(colorScheme) : MenuBarPalette.ink(colorScheme)
                        )
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if !isCompleted, let dueDate = task.dueDate,
                       DailyLessonAnalytics.dueBucket(for: dueDate, now: .now) == .overdue {
                        Text("逾期")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(MenuBarPalette.cinnabar(colorScheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(MenuBarPressButtonStyle())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? MenuBarPalette.hoverFill(colorScheme) : .clear)
        )
        .onHover(perform: onHover)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(task.title)，\(isCompleted ? "已完成" : "未完成")")
    }
}
