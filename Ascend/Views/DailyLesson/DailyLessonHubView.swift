import SwiftUI

/// 今日页的日课总装区：概览、快速新增、今日待办、习惯打卡、即将到来与功成印记。
struct DailyLessonHubView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var quickAddText = ""
    @FocusState private var isQuickAddFocused: Bool
    @State private var editingTask: DailyTask?
    @State private var showsUpcoming = false
    @State private var showsCompletedTodos = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            DailyTaskQuickAddField(text: $quickAddText, onSubmit: addQuickTodo, isFocused: $isQuickAddFocused)

            DailyHabitStripView(onEdit: { task in
                editingTask = task
            })

            todoSection
            upcomingSection

            if allScheduledDone {
                completionSeal
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: allScheduledDone)
        .sheet(item: $editingTask) { task in
            DailyTaskComposerSheet(editing: task)
        }
    }

    // MARK: 头部

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AscendTheme.isXuanqing ? "今日功课" : "今日清单")
                    .font(.system(.title3, design: AscendTheme.titleDesign))
                    .bold()
                Text(overviewSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                appState.isPresentingDailyTaskComposer = true
            } label: {
                Label("新增", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(AscendTheme.gold)
            .help("新增待办或习惯（⌘N）")
        }
    }

    private var overviewSummary: String {
        let totals = appState.todayDailyTaskTotals()
        let focusMinutes = appState.todayFocusMinutes()
        if totals.total == 0 {
            return "写下今天想完成的学习目标"
        }
        var summary = "已完成 \(totals.done)/\(totals.total) 项"
        if focusMinutes > 0 {
            summary += " · 专注 \(focusMinutes) 分钟"
        }
        return summary
    }

    // MARK: 待办

    @ViewBuilder
    private var todoSection: some View {
        let (open, completed) = appState.todayTodoGroups()
        if !open.isEmpty || !completed.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(AscendTheme.isXuanqing ? "今日待办" : "待办事项")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 2) {
                    ForEach(open) { task in
                        DailyTodoRowView(task: task, onEdit: { editingTask = $0 })
                    }

                    if !completed.isEmpty {
                        Button {
                            guard !reduceMotion else { showsCompletedTodos.toggle(); return }
                            withAnimation(.easeOut(duration: 0.2)) { showsCompletedTodos.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showsCompletedTodos ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("已完成 \(completed.count)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)

                        if showsCompletedTodos {
                            ForEach(completed) { task in
                                DailyTodoRowView(task: task, showsCompletionTime: true)
                            }
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
    }

    // MARK: 即将到来

    @ViewBuilder
    private var upcomingSection: some View {
        let upcoming = appState.upcomingTodos()
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    guard !reduceMotion else { showsUpcoming.toggle(); return }
                    withAnimation(.easeOut(duration: 0.2)) { showsUpcoming.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showsUpcoming ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                        Text(AscendTheme.isXuanqing ? "前路有期" : "即将到来")
                            .font(.caption)
                        Text("\(upcoming.count)")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AscendTheme.gold.opacity(0.14))
                            .foregroundStyle(AscendTheme.gold)
                            .clipShape(.capsule)
                        Spacer()
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                if showsUpcoming {
                    VStack(spacing: 2) {
                        ForEach(upcoming) { task in
                            DailyTodoRowView(task: task, onEdit: { editingTask = $0 })
                        }
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: 功成印记

    private var allScheduledDone: Bool {
        let totals = appState.todayDailyTaskTotals()
        return totals.total > 0 && totals.done == totals.total
    }

    private var completionSeal: some View {
        HStack(spacing: 10) {
            ClassicalSealMark(text: "功成", style: .gold, size: 24)
            Text(AscendTheme.isXuanqing ? "今日功课已毕，香尽功不散" : "今日清单全部完成，干得漂亮")
                .font(.subheadline)
                .foregroundStyle(AscendTheme.gold)
            Spacer()
        }
        .padding(10)
        .background(AscendTheme.gold.opacity(0.07))
        .clipShape(.rect(cornerRadius: AscendTheme.Radius.control))
        .accessibilityElement(children: .combine)
    }

    // MARK: 行为

    private func addQuickTodo() {
        guard !quickAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        appState.addDailyTask(title: quickAddText)
        quickAddText = ""
    }
}
